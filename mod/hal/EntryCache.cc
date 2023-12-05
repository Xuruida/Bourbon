#include "mod/hal/EntryCache.h"

namespace hal {

    size_t kValueCacheThreshold = 128;
    int kEntryCacheSize = 128 * 1024 * 1024;
    
    size_t GetAllocSize(size_t v) {
        // compute the next highest power of 2 of 32-bit v
        v--;
        v |= v >> 1;
        v |= v >> 2;
        v |= v >> 4;
        v |= v >> 8;
        v |= v >> 16;
        v++;
        return v;
    }

    bool EntryCache::InsertInternal(const Slice &key, uint64_t vlog_addr, const Slice &new_value, bool is_try, Handle *handle) {
        Handle *lookup_handle = (handle == nullptr) ? cache_->Lookup(key) : handle;
        if (lookup_handle != nullptr) {
            // second insert
            EntryItem *item = cache_->GetValue(lookup_handle);
            item->vlog_addr = vlog_addr;
            item->vlog_vsize = new_value.size();
            item->setDirty();

            if (new_value.size() <= kValueCacheThreshold) {
                uint32_t target_size = GetAllocSize(new_value.size());

                // allocate new item
                if (target_size > item->item_max_size) {
                    EntryItem *new_item = NewEntryItem(target_size);
                    CopyEntryItemMeta(new_item, item);
                    new_item->SetItem(new_value, true);
                    cache_->SetValue(lookup_handle, new_item);

                    int delta = target_size - item->item_max_size;
                    reinterpret_cast<EntryLRUHandle *>(lookup_handle)->charge += delta;
                    cache_->UsageChange(key, delta);
                    delete item;
                } else {
                    item->SetItem(new_value, true);
                }
            }
            cache_->Release(lookup_handle);
            return true;

        } else if (!is_try) {
            // first insert
            EntryItem *item = NewEntryItem(0);
            item->vlog_addr = vlog_addr;
            item->vlog_vsize = new_value.size();
            Handle *h = cache_->Insert(key, item, EntryItemSize, nullptr);
            Release(h);
            return true;
        }
        return false;
    }

    bool EntryCache::Lookup(const Slice &key, std::string *value) {
        Handle *lookup_handle = cache_->Lookup(key);

        // case 1: not found
        if (lookup_handle == nullptr) {
            return false;
        }

        EntryItem *item = cache_->GetValue(lookup_handle);

        // case 2: has value
        if (item->item_size > 0) {
            item->GetItem(value);
            Release(lookup_handle);
            return true;
        }

        // case 3: from vlog / second insert
        *value = std::move(vlog_->ReadRecord(item->vlog_addr, item->vlog_vsize));
        InsertInternal(key, item->vlog_addr, (Slice) (*value), false, lookup_handle);
        return true;
    }
}