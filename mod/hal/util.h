#include <x86intrin.h>
#include <cstdint>

namespace hal {
    uint64_t Now() {
        unsigned int dummy = 0;
        return __rdtscp(&dummy);
    }
};