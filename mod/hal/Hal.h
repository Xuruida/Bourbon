#ifndef HAL_LEVELDB_H
#define HAL_LEVELDB_H

#include "db/dbformat.h"
#include "mod/hal/CirQueue.h"

#include <unordered_map>

template<>
class std::hash<hal::KeyType> {
public:
    size_t operator()(const hal::KeyType& k) const {
        return std::hash<std::string>()(k.rep_);
    }
};

namespace hal {

    extern size_t default_queue_size;
    enum HalModeMask : uint32_t {
        kHalEnabled = 1 << 0,
        kHalCompactionEnabled = 1 << 1,
        kHalLearnedScheduleEnabled = 1 << 2,
        kHalEntryCacheEnabled = 1 << 3
    };

    extern uint32_t mode;

    class SSTHotStats {
    public:
        std::unordered_map<KeyType, int64_t> access_map;
        CircularQueue<CircularQueueItem> cq;
        uint64_t total_accesses = 0;

        SSTHotStats();

        inline double getScore() {
            return cq.getScore();
        }
        
        void add(const KeyType &key);
    };
};

#endif