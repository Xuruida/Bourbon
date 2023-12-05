#ifndef HAL_CIRCULAR_QUEUE_H_
#define HAL_CIRCULAR_QUEUE_H_

#include "mod/hal/Hal.h"

#include <mutex>
#include <vector>

// #define HAL_MUTEX_ENABLED
namespace hal {

using KeyType = leveldb::InternalKey;
using TimestampType = uint64_t;

struct CircularQueueItem {
    KeyType key;
    TimestampType timestamp;
    inline TimestampType score() { return timestamp; }
};

template <typename T>
class CircularQueue {
private:
// #ifdef HAL_MUTEX_ENABLED
//     std::mutex mutex_;
// #endif
    std::vector<T> queue_;
    size_t front_ = 0, rear_ = 0;
    size_t capacity_ = 0;
    
public:
    CircularQueue(int size) : queue_(size + 1), front_(0), rear_(0), capacity_(size + 1) {}
    ~CircularQueue() {}

    inline size_t getSize() {
        return (rear_ - front_ + capacity_) % capacity_;
    }

    bool enQueue(const T &value) {
// #ifdef HAL_MUTEX_ENABLED
//         std::lock_guard<std::mutex> lg(mutex_);
// #endif
        if (isFull()) {
            // return false;
            front_ = (front_ + 1) % capacity_;
        }
        queue_[rear_] = value;
        rear_ = (rear_ + 1) % capacity_;
        return true;
    }
    
    bool deQueue() {
// #ifdef HAL_MUTEX_ENABLED
//         std::lock_guard<std::mutex> lg(mutex_);
// #endif
        if (isEmpty())
            return false;
        front_ = (front_ + 1) % capacity_;
        return true;
    }
    
    T Front() {
        if (isEmpty())
            return {};
        return queue_[front_];
    }
    
    T Rear() {
        if (isEmpty())
            return {};
        return queue_[(rear_ + capacity_ - 1) % capacity_];
    }
    
    bool isEmpty() {
        return front_ == rear_;
    }
    
    bool isFull() {
        return (rear_ + 1) % capacity_ == front_;
    }

    double getScore() {
        if (isEmpty())
            return -1;
        return (Rear().score() - Front().score()) / static_cast<double>(getSize());
    }
};

}

#endif