// Copyright (c) 2011 The LevelDB Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file. See the AUTHORS file for names of contributors.

#ifndef HAL_ENTRY_CACHE_INTERNAL_H_
#define HAL_ENTRY_CACHE_INTERNAL_H_

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

// #include "db/db_impl.h"
#include "db/write_batch_internal.h"
#include "leveldb/cache.h"
#include "port/port.h"
#include "port/thread_annotations.h"
#include "util/hash.h"
#include "util/mutexlock.h"

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

constexpr uint8_t DirtyMask = 0x01;
// constexpr uint8_t ValueMask = 0x02;

extern int BatchWriteThreshold;

struct EntryItem {
  uint8_t status;
  uint64_t vlog_addr;
  uint32_t vlog_vsize;
  uint32_t item_max_size;
  uint32_t item_size;
  char value[0];
  
  EntryItem() = delete;
  bool isDirty() const {
    return status & DirtyMask;
  }

  void setDirty() {
    status |= DirtyMask;
  }

  void GetItem(string *v) {
    v->assign(value, item_size);
  }

  bool SetItem(const Slice &v, bool update) {
    if (v.size() > item_max_size)
      return false;
    item_size = v.size();
    memcpy(value, v.data(), item_size);
    if (update)
      setDirty();
    return true;
  }
};

constexpr size_t EntryItemSize = sizeof(EntryItem);

// LRU
// Insert(K + Vlog_addr)
// Lookup(K + Vlog_addr + value)

// An entry is a variable length heap-allocated structure.  Entries
// are kept in a circular doubly linked list ordered by access time.

struct EntryLRUHandle {
  EntryItem* value;
  void (*deleter)(const Slice&, void* value);
  EntryLRUHandle* next_hash;
  EntryLRUHandle* next;
  EntryLRUHandle* prev;
  size_t charge;  // TODO(opt): Only allow uint32_t?
  size_t key_length;
  bool in_cache;     // Whether entry is in the cache.
  uint32_t refs;     // References, including cache reference, if present.
  uint32_t hash;     // Hash of key(); used for fast sharding and comparisons
  char key_data[1];  // Beginning of key

  Slice key() const {
    // next_ is only equal to this if the LRU handle is the list head of an
    // empty list. List heads never have meaningful keys.
    assert(next != this);

    return Slice(key_data, key_length);
  }
};

// We provide our own simple hash table since it removes a whole bunch
// of porting hacks and is also faster than some of the built-in hash
// table implementations in some of the compiler/runtime combinations
// we have tested.  E.g., readrandom speeds up by ~5% over the g++
// 4.4.3's builtin hashtable.
class HandleTable {
 public:
  HandleTable() : length_(0), elems_(0), list_(nullptr) { Resize(); }
  ~HandleTable() { delete[] list_; }

  EntryLRUHandle* Lookup(const Slice& key, uint32_t hash) {
    return *FindPointer(key, hash);
  }

  EntryLRUHandle* Insert(EntryLRUHandle* h) {
    EntryLRUHandle** ptr = FindPointer(h->key(), h->hash);
    EntryLRUHandle* old = *ptr;
    h->next_hash = (old == nullptr ? nullptr : old->next_hash);
    *ptr = h;
    if (old == nullptr) {
      ++elems_;
      if (elems_ > length_) {
        // Since each cache entry is fairly large, we aim for a small
        // average linked list length (<= 1).
        Resize();
      }
    }
    return old;
  }

  EntryLRUHandle* Remove(const Slice& key, uint32_t hash) {
    EntryLRUHandle** ptr = FindPointer(key, hash);
    EntryLRUHandle* result = *ptr;
    if (result != nullptr) {
      *ptr = result->next_hash;
      --elems_;
    }
    return result;
  }

 private:
  // The table consists of an array of buckets where each bucket is
  // a linked list of cache entries that hash into the bucket.
  uint32_t length_;
  uint32_t elems_;
  EntryLRUHandle** list_;

  // Return a pointer to slot that points to a cache entry that
  // matches key/hash.  If there is no such cache entry, return a
  // pointer to the trailing slot in the corresponding linked list.
  EntryLRUHandle** FindPointer(const Slice& key, uint32_t hash) {
    EntryLRUHandle** ptr = &list_[hash & (length_ - 1)];
    while (*ptr != nullptr && ((*ptr)->hash != hash || key != (*ptr)->key())) {
      ptr = &(*ptr)->next_hash;
    }
    return ptr;
  }

  void Resize() {
    uint32_t new_length = 4;
    while (new_length < elems_) {
      new_length *= 2;
    }
    EntryLRUHandle** new_list = new EntryLRUHandle*[new_length];
    memset(new_list, 0, sizeof(new_list[0]) * new_length);
    uint32_t count = 0;
    for (uint32_t i = 0; i < length_; i++) {
      EntryLRUHandle* h = list_[i];
      while (h != nullptr) {
        EntryLRUHandle* next = h->next_hash;
        uint32_t hash = h->hash;
        EntryLRUHandle** ptr = &new_list[hash & (new_length - 1)];
        h->next_hash = *ptr;
        *ptr = h;
        h = next;
        count++;
      }
    }
    assert(elems_ == count);
    delete[] list_;
    list_ = new_list;
    length_ = new_length;
  }
};

// A single shard of sharded cache.
class EntryLRUCache {
 public:
  EntryLRUCache();
  ~EntryLRUCache();

  // Separate from constructor so caller can easily make an array of LRUCache
  void SetCapacity(size_t capacity) { capacity_ = capacity; }

  // Like Cache methods, but with an extra "hash" parameter.
  Cache::Handle* Insert(const Slice& key, uint32_t hash, void* value,
                        size_t charge,
                        void (*deleter)(const Slice& key, void* value));
  Cache::Handle* Lookup(const Slice& key, uint32_t hash);
  void Release(Cache::Handle* handle);
  void Erase(const Slice& key, uint32_t hash);
  void Prune();
  size_t TotalCharge() const {
    MutexLock l(&mutex_);
    return usage_;
  }

  void SetDB(DB *db) {
    db_ = db;
  }

  WriteBatch *GetWriteBatchPtr() {
    return &wb_;
  }
  
  void UsageChange(int delta);

 private:
  void LRU_Remove(EntryLRUHandle* e);
  void LRU_Append(EntryLRUHandle* list, EntryLRUHandle* e);
  void Ref(EntryLRUHandle* e);
  void Unref(EntryLRUHandle* e);
  bool FinishErase(EntryLRUHandle* e) EXCLUSIVE_LOCKS_REQUIRED(mutex_);

  // Hal:
  WriteBatch wb_;
  DB *db_ = nullptr;
  WriteOptions wo_;

  // Initialized before use.
  size_t capacity_;

  // mutex_ protects the following state.
  mutable port::Mutex mutex_;
  size_t usage_ GUARDED_BY(mutex_);

  // Dummy head of LRU list.
  // lru.prev is newest entry, lru.next is oldest entry.
  // Entries have refs==1 and in_cache==true.
  EntryLRUHandle lru_ GUARDED_BY(mutex_);

  // Dummy head of in-use list.
  // Entries are in use by clients, and have refs >= 2 and in_cache==true.
  EntryLRUHandle in_use_ GUARDED_BY(mutex_);

  HandleTable table_ GUARDED_BY(mutex_);
};

static const int kNumShardBits = 4;
static const int kNumShards = 1 << kNumShardBits;

class EntryShardedLRUCache {
 private:
  EntryLRUCache shard_[kNumShards];
  port::Mutex id_mutex_;
  uint64_t last_id_;

  static inline uint32_t HashSlice(const Slice& s) {
    return Hash(s.data(), s.size(), 0);
  }

  static uint32_t Shard(uint32_t hash) { return hash >> (32 - kNumShardBits); }

 public:
  explicit EntryShardedLRUCache(size_t capacity) : last_id_(0) {
    const size_t per_shard = (capacity + (kNumShards - 1)) / kNumShards;
    for (int s = 0; s < kNumShards; s++) {
      shard_[s].SetCapacity(per_shard);
    }
  }

  void SetDBPerShard(DB *db) {
    for (int s = 0; s < kNumShards; s++) {
      shard_[s].SetDB(db);
    }
  }

  virtual ~EntryShardedLRUCache() {}
  virtual Handle* Insert(const Slice& key, void* value, size_t charge,
                         void (*deleter)(const Slice& key, void* value)) {
    const uint32_t hash = HashSlice(key);
    return shard_[Shard(hash)].Insert(key, hash, value, charge, deleter);
  }
  virtual Handle* Lookup(const Slice& key) {
    const uint32_t hash = HashSlice(key);
    return shard_[Shard(hash)].Lookup(key, hash);
  }
  virtual void Release(Handle* handle) {
    EntryLRUHandle* h = reinterpret_cast<EntryLRUHandle*>(handle);
    shard_[Shard(h->hash)].Release(handle);
  }
  virtual void Erase(const Slice& key) {
    const uint32_t hash = HashSlice(key);
    shard_[Shard(hash)].Erase(key, hash);
  }
  virtual EntryItem* GetValue(Handle* handle) {
    return reinterpret_cast<EntryLRUHandle*>(handle)->value;
  }
  virtual void SetValue(Handle* handle, EntryItem *new_item) {
    reinterpret_cast<EntryLRUHandle*>(handle)->value = new_item;
  }

  void UsageChange(const Slice& key, int delta) {
    const uint32_t hash = HashSlice(key);
    shard_[Shard(hash)].UsageChange(delta);
  }

  int GetShardWriteBatchSize(const Slice& key) {
    const uint32_t hash = HashSlice(key);
    return WriteBatchInternal::Count(shard_[Shard(hash)].GetWriteBatchPtr());
  }

  virtual uint64_t NewId() {
    MutexLock l(&id_mutex_);
    return ++(last_id_);
  }
  virtual void Prune() {
    for (int s = 0; s < kNumShards; s++) {
      shard_[s].Prune();
    }
  }
  virtual size_t TotalCharge() const {
    size_t total = 0;
    for (int s = 0; s < kNumShards; s++) {
      total += shard_[s].TotalCharge();
    }
    return total;
  }
};

EntryShardedLRUCache* NewEntryLRUCache(size_t capacity);

EntryItem *NewEntryItem(size_t item_max_size);

void CopyEntryItemMeta(EntryItem *dst, EntryItem *src);

}  // namespace hal

#endif