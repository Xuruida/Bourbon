// Copyright (c) 2011 The LevelDB Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file. See the AUTHORS file for names of contributors.

#include "mod/hal/CacheInternal.h"

using namespace leveldb;
using Handle = Cache::Handle;

namespace hal {

// LRU cache implementation
//
// Cache entries have an "in_cache" boolean indicating whether the cache has a
// reference on the entry.  The only ways that this can become false without the
// entry being passed to its "deleter" are via Erase(), via Insert() when
// an element with a duplicate key is inserted, or on destruction of the cache.
//
// The cache keeps two linked lists of items in the cache.  All items in the
// cache are in one list or the other, and never both.  Items still referenced
// by clients but erased from the cache are in neither list.  The lists are:
// - in-use:  contains the items currently referenced by clients, in no
//   particular order.  (This list is used for invariant checking.  If we
//   removed the check, elements that would otherwise be on this list could be
//   left as disconnected singleton lists.)
// - LRU:  contains the items not currently referenced by clients, in LRU order
// Elements are moved between these lists by the Ref() and Unref() methods,
// when they detect an element in the cache acquiring or losing its only
// external reference.

// Entry Item in entry cache
// Dirty Bit(1) + VlogAddr(8) + ValueSize(8)

int BatchWriteThreshold = 10;

EntryLRUCache::EntryLRUCache() : capacity_(0), usage_(0) {
  // Make empty circular linked lists.
  lru_.next = &lru_;
  lru_.prev = &lru_;
  in_use_.next = &in_use_;
  in_use_.prev = &in_use_;
  wb_.Clear();
}

EntryLRUCache::~EntryLRUCache() {
  //assert(in_use_.next == &in_use_);  // Error if caller has an unreleased handle
  for (EntryLRUHandle* e = lru_.next; e != &lru_;) {
    EntryLRUHandle* next = e->next;
    assert(e->in_cache);
    e->in_cache = false;
    assert(e->refs == 1);  // Invariant of lru_ list.
    Unref(e);
    e = next;
  }
}

void EntryLRUCache::UsageChange(int delta) {
  MutexLock l(&mutex_);
  usage_ += delta;
}

void EntryLRUCache::Ref(EntryLRUHandle* e) {
  if (e->refs == 1 && e->in_cache) {  // If on lru_ list, move to in_use_ list.
    LRU_Remove(e);
    LRU_Append(&in_use_, e);
  }
  e->refs++;
}

void EntryLRUCache::Unref(EntryLRUHandle* e) {
  assert(e->refs > 0);
  e->refs--;
  if (e->refs == 0) {  // Deallocate.
    assert(!e->in_cache);
    // (*e->deleter)(e->key(), e->value);

    // Dirty Push into WriteBatch wb_
    if (e->value->isDirty()) {
      char buffer[sizeof(uint64_t) + sizeof(uint32_t)];
      EncodeFixed64(buffer, e->value->vlog_addr);
      EncodeFixed32(buffer + sizeof(uint64_t), e->value->vlog_vsize);
      wb_.Put(e->key(), (Slice) {buffer, sizeof(uint64_t) + sizeof(uint32_t)});

      // Batch Put
      if (WriteBatchInternal::Count(&wb_) >= BatchWriteThreshold) {
        db_->Write(wo_, &wb_);
        wb_.Clear();
      }
    }
    free(e->value);

    free(e);
  } else if (e->in_cache && e->refs == 1) {
    // No longer in use; move to lru_ list.
    LRU_Remove(e);
    LRU_Append(&lru_, e);
  }
}

void EntryLRUCache::LRU_Remove(EntryLRUHandle* e) {
  e->next->prev = e->prev;
  e->prev->next = e->next;
}

void EntryLRUCache::LRU_Append(EntryLRUHandle* list, EntryLRUHandle* e) {
  // Make "e" newest entry by inserting just before *list
  e->next = list;
  e->prev = list->prev;
  e->prev->next = e;
  e->next->prev = e;
}

Cache::Handle* EntryLRUCache::Lookup(const Slice& key, uint32_t hash) {
  MutexLock l(&mutex_);
  EntryLRUHandle* e = table_.Lookup(key, hash);
  if (e != nullptr) {
    Ref(e);
  }
  return reinterpret_cast<Cache::Handle*>(e);
}

void EntryLRUCache::Release(Cache::Handle* handle) {
  MutexLock l(&mutex_);
  Unref(reinterpret_cast<EntryLRUHandle*>(handle));
}

Cache::Handle* EntryLRUCache::Insert(const Slice& key, uint32_t hash, void* value,
                                size_t charge,
                                void (*deleter)(const Slice& key,
                                                void* value)) {
  MutexLock l(&mutex_);

  EntryLRUHandle* e =
      reinterpret_cast<EntryLRUHandle*>(malloc(sizeof(EntryLRUHandle) - 1 + key.size()));
  e->value = reinterpret_cast<EntryItem *>(value);
  e->deleter = deleter;
  e->charge = charge;
  e->key_length = key.size();
  e->hash = hash;
  e->in_cache = false;
  e->refs = 1;  // for the returned handle.
  memcpy(e->key_data, key.data(), key.size());

  if (capacity_ > 0) {
    e->refs++;  // for the cache's reference.
    e->in_cache = true;
    LRU_Append(&in_use_, e);
    usage_ += charge;
    FinishErase(table_.Insert(e));
  } else {  // don't cache. (capacity_==0 is supported and turns off caching.)
    // next is read by key() in an assert, so it must be initialized
    e->next = nullptr;
  }
  while (usage_ > capacity_ && lru_.next != &lru_) {
    EntryLRUHandle* old = lru_.next;
    assert(old->refs == 1);
    bool erased = FinishErase(table_.Remove(old->key(), old->hash));
    if (!erased) {  // to avoid unused variable when compiled NDEBUG
      assert(erased);
    }
  }

  return reinterpret_cast<Cache::Handle*>(e);
}

// If e != nullptr, finish removing *e from the cache; it has already been
// removed from the hash table.  Return whether e != nullptr.
bool EntryLRUCache::FinishErase(EntryLRUHandle* e) {
  if (e != nullptr) {
    assert(e->in_cache);
    LRU_Remove(e);
    e->in_cache = false;
    usage_ -= e->charge;
    Unref(e);
  }
  return e != nullptr;
}

void EntryLRUCache::Erase(const Slice& key, uint32_t hash) {
  MutexLock l(&mutex_);
  FinishErase(table_.Remove(key, hash));
}

void EntryLRUCache::Prune() {
  MutexLock l(&mutex_);
  while (lru_.next != &lru_) {
    EntryLRUHandle* e = lru_.next;
    assert(e->refs == 1);
    bool erased = FinishErase(table_.Remove(e->key(), e->hash));
    if (!erased) {  // to avoid unused variable when compiled NDEBUG
      assert(erased);
    }
  }
}

EntryShardedLRUCache* NewEntryLRUCache(size_t capacity) { return new EntryShardedLRUCache(capacity); }

EntryItem *NewEntryItem(size_t item_max_size) {
  EntryItem *it = reinterpret_cast<EntryItem *>(malloc(EntryItemSize + item_max_size));
  it->status = 0;
  it->vlog_addr = 0;
  it->vlog_vsize = 0;
  it->item_max_size = item_max_size;
  it->item_size = 0;
  return it;
}

void CopyEntryItemMeta(EntryItem *dst, EntryItem *src) {
  dst->status = src->status;
  dst->vlog_addr = src->vlog_addr;
  dst->vlog_vsize = src->vlog_vsize;
}

}  // namespace hal