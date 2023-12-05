#include "mod/hal/Hal.h"
#include "util.h"

namespace hal {

    uint32_t mode = 0;
    size_t default_queue_size = 256;

    SSTHotStats::SSTHotStats() : cq(default_queue_size), total_accesses(0) {}

    void SSTHotStats::add(const KeyType &key) {
        total_accesses++;
        cq.enQueue({key, hal::Now()});
    }

};