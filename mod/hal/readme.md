# HaL

HaL is abbv. for `Hotspot-aware Learned index`

## Design

- Add hash table and RingBuffer for each SSTable.
- Estimate hotness by calculating frequency.
- Selecting compacted SSTable by hotness information.
- A small cache for hot keys.

source code in `mod/hal`:

### SST Hotness Stats

SSTHotStats.h

```cpp
struct CircularQueueItem {
    KeyType key;
    TimeStamp timestamp;
};

class CircularQueue {
    ...
};

class SSTHotStats {
    std::unordered_map<KeyType, int64_t> access_map;
    CircularQueue cq;
};
```

**KeyType的选择**
- internal_key附带版本信息，user_key不附带

- Hal.h 声明了LevelDB中需要用到的class
- util.h 一些需要用到的helper函数(hal::Now())
- CirQueue.h 循环队列

**FileMetaData**加入一个`std::shared_ptr<hal::SSTHotStats>`，通过该接口修改与统计SST的访问信息。


### Entry Cache

- fast get (hash table)

- Hash Table + Update Supported.

- WiscKey 在Put的时候将写入的数据改成了Vlog...

### 原型设计

#### Overview

- ShardedLRUCache + Dirty bit
- KV分离：放热数据的值 + （第二次访问）热数据的VLog地址，便于写下去
- DirtyWriteBatch (脏KV刷入Memtable)

Extra:

- Compaction时，检验版本丢弃老版本

Cache Elements:

- Key (Slice &key)
- Value:
    - Status: Dirty Bit: (1B)
    - Addr: (VlogAddr) (8B)
    - vlog_addr;
    - Actual Value: (second access) (?B) (可能需要内存池)

需要修改的部分：

- LRU加入Dirty位，换出时需要加入DirtyWriteBatch，继承LRUCache.
- DB::Impl 初始化加入db_


#### EntryCache逻辑

- Unref的时候检测是否Dirty插入wb_
- wb_达到阈值Write进db_

#### DB Impl 逻辑

**Status DBImpl::Get(const ReadOptions& options, const Slice& key,std::string* value)**

- EntryCache Lookup
    - 命中：返回value
        - item_size == 0: 取ValueLog，Vlog的值也取进去(直接重新分配 e->value)
        - item_size > 0: 直接返回
    - 未命中：等到最后值取到
        - 插入item_size == 0的item

**Status DBImpl::Put(const WriteOptions& o, const Slice& key, const Slice& val)**

一定要插入ValueLog。

- Lookup
    - 命中：直接原地更新，set dirty
    - 未命中：正常逻辑

