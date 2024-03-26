// HaL EntryCache implementation by xiaodaqwq
// 2023.12

#ifndef HAL_ENTRY_CACHE_H_
#define HAL_ENTRY_CACHE_H_

#include <iostream>

#include "mod/hal/CacheInternal.h"
#include "mod/Vlog.h"
#include "leveldb/slice.h"

using Slice = leveldb::Slice;
using Cache = leveldb::Cache;

namespace hal {
    // Cache smaller than kValueCacheThreshold Value into entry cache.
    extern size_t kValueCacheThreshold;
    
    // 128M entry cache
    extern size_t kEntryCacheSizeMB;

    extern size_t kEntryCacheSize;


    extern bool kEntryCacheDebugOutput;
    class EntryCache {
        public:
            EntryCache(size_t size, DB *db, adgMod::VLog *vlog) : cache_(NewEntryLRUCache(size)), db_(db), vlog_(vlog) {
                std::cout << "EntryCache size: " << size / 1024 / 1024 << "MB" << std::endl;
                cache_->SetDBPerShard(db_);
            }

            ~EntryCache() {
                delete cache_;
            }

            // Lookup given key, result store into *value
            bool Lookup(const Slice &key, std::string *value);

            void Release(Handle *handle) {
                cache_->Release(handle);
            }

            void Erase(const Slice& key) {
                cache_->Erase(key);
            }

            EntryItem* Value(Handle *handle) {
                return cache_->GetValue(handle);
            }

            inline bool Insert(const Slice &key, uint64_t vlog_addr, std::string *new_value) {
                return InsertInternal(key, vlog_addr, (Slice) (*new_value), false, nullptr);
            }

            inline bool TryInsert(const Slice &key, uint64_t vlog_addr, const Slice &new_value) {
                return InsertInternal(key, vlog_addr, new_value, true, nullptr);
            }

            inline adgMod::VLog *Vlog() {
                return vlog_;
            }

            inline EntryShardedLRUCache *Cache() {
                return cache_;
            }

        private:
            bool InsertInternal(const Slice &key, uint64_t vlog_addr, const Slice &new_value, bool is_try, Handle *handle);
            EntryShardedLRUCache *cache_ = nullptr;
            DB *db_;
            adgMod::VLog *vlog_ = nullptr;
        
        public:
            int getCase1 = 0, getCase2 = 0, getCase3 = 0;
    };
    
};

#endif