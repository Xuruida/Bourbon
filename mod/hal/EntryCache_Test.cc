#include <iostream>
#include "EntryCache.h"
#include "mod/hal/Hal.h"

#include "mod/util.h"
#include "leveldb/db.h"
#include "db/db_impl.h"

#include "util/testharness.h"

namespace leveldb {

using std::string;
using std::cout;
using std::endl;

class EntryCacheTest {
   public:
    string db_basic_test_path, db_db_test_path;
    DB* db_;
    Status s;
    Options o;

    EntryCacheTest() {
        hal::mode |= hal::HalModeMask::kHalEntryCacheEnabled;
        adgMod::MOD = 7;
        db_basic_test_path = test::TmpDir() + "/entry_cache_basic_test";
        db_db_test_path = test::TmpDir() + "/entry_cache_db_test";
        o.create_if_missing = true;
    }

    ~EntryCacheTest() {
        DestroyDB(db_basic_test_path, o);
        DestroyDB(db_db_test_path, o);
    }
};

TEST(EntryCacheTest, BasicTest) {
    cout << "Opening DB: " << db_basic_test_path << endl;
    s = DB::Open(o, db_basic_test_path, &db_);
    ASSERT_EQ(s.ok(), true);
    DBImpl *db_impl = dynamic_cast<DBImpl*>(db_);
    ASSERT_EQ(db_impl != nullptr, true);

    hal::EntryCache *entry_cache = db_impl->entry_cache;

    std::vector<std::pair<Slice, Slice>> kvs{
        {"key1", "value1"},
        {"key2", "value2"},
        {"key3", "value3"},
        {"key4", "value4"},
        {"key5", "value5"}
    };

    std::vector<uint64_t> addrs {1, 2, 3, 4, 5};

    string value;

    bool found = true;
    bool success = false;

    // Lookup case 1: not found
    found = entry_cache->Lookup(kvs[0].first, &value);
    ASSERT_EQ(found, false);
    
    // TryInsert case 1: not found
    addrs[0] = entry_cache->Vlog()->AddRecord(kvs[0].first, kvs[0].second);
    cout << "Insert Vlog Addr: " << addrs[0] << endl;
    found = entry_cache->TryInsert(kvs[0].first, addrs[0], kvs[0].second);
    ASSERT_EQ(found, false);

    // Insert case 1: only vlog addr
    string v0 = kvs[0].second.ToString();
    success = entry_cache->Insert(kvs[0].first, addrs[0], &v0);
    ASSERT_EQ(success, true);

    // Lookup case 3: only vlog addr, and caching to vcache
    found = entry_cache->Lookup(kvs[0].first, &value);
    ASSERT_EQ(found, true);
    ASSERT_EQ(value, kvs[0].second.ToString());

    // Lookup case 2: from vcache
    value.clear();
    found = entry_cache->Lookup(kvs[0].first, &value);
    ASSERT_EQ(found, true);
    ASSERT_EQ(value, kvs[0].second.ToString());

    // Update:
    value.clear();
    Slice v0new{"valuevalue0"};
    auto a0new = entry_cache->Vlog()->AddRecord(kvs[0].first, v0new);
    success = entry_cache->TryInsert(kvs[0].first, a0new, v0new);
    ASSERT_EQ(success, true);

    // Lookup case 2: new value
    value.clear();
    found = entry_cache->Lookup(kvs[0].first, &value);
    ASSERT_EQ(found, true);
    ASSERT_EQ(v0new.ToString(), value);
    
    // Erase
    entry_cache->Erase(kvs[0].first);
    
    // Lookup not found...
    value.clear();
    found = entry_cache->Lookup(kvs[0].first, &value);
    ASSERT_EQ(found, false);

    cout << "basic test done successfully !!!" << endl;
    DestroyDB(db_basic_test_path, o);
}

TEST(EntryCacheTest, DBTest) {
    cout << "Opening DB: " << db_db_test_path << endl;
    s = DB::Open(o, db_db_test_path, &db_);
    cout << s.ToString() << endl;
    ASSERT_EQ(s.ok(), true);
    DBImpl *db_impl = dynamic_cast<DBImpl*>(db_);
    ASSERT_EQ(db_impl != nullptr, true);

    std::vector<std::pair<Slice, Slice>> kvs{
        {"key1", "value1"},
        {"key2", "value2"},
        {"key3", "value3"},
        {"key4", "value4"},
        {"key5", "value5"}
    };

    std::vector<Slice> new_values {
        "valuevaluevaluevaluevalue1",
        "valuevaluevaluevaluevalue2",
        "valuevaluevaluevaluevalue3",
        "valuevaluevaluevaluevalue4",
        "valuevaluevaluevaluevalue5"
    };

    auto wo = WriteOptions();
    auto ro = ReadOptions();

    std::string value;
    Status s;
    
    // Put and get kv 0
    s = db_impl->Put(wo, kvs[0].first, kvs[0].second);
    cout << "Put: " << kvs[0].first.ToString() << " " << kvs[0].second.ToString() << endl;
    ASSERT_EQ(s.ok(), true);

    s = db_impl->Get(ro, kvs[0].first, &value);
    cout << "Get: " << kvs[0].first.ToString() << " " << value << endl;
    ASSERT_EQ(s.ok(), true);
    ASSERT_EQ(value, kvs[0].second.ToString());

    // Get not exist keys twice
    for (int i = 1; i < kvs.size(); i++) {
        s = db_impl->Get(ro, kvs[i].first, &value);
        ASSERT_EQ(s.IsNotFound(), true);
    }

    for (int i = 1; i < kvs.size(); i++) {
        s = db_impl->Get(ro, kvs[i].first, &value);
        ASSERT_EQ(s.IsNotFound(), true);
    }

    for (int i = 1; i < 4; i++) {
        s = db_impl->Put(wo, kvs[i].first, kvs[i].second);
        cout << "Put: " << kvs[i].first.ToString() << " " << kvs[i].second.ToString() << endl;
        ASSERT_EQ(s.ok(), true);
    }

    for (int i = 1; i < 4; i++) {
        s = db_impl->Get(ro, kvs[i].first, &value);
        ASSERT_EQ(s.ok(), true);
        ASSERT_EQ(value, kvs[i].second.ToString());
        cout << "Get: " << kvs[i].first.ToString() << "->" << value << " " << value << endl;
    }

    //
    cout << endl << "====== BatchWriteUpdateTest ======" << endl << endl;
    for (int j = 1; j <= hal::BatchWriteThreshold * 5; j++) {
        int idx = j % kvs.size();
        s = db_impl->Put(wo, kvs[idx].first, new_values[idx]);
        ASSERT_EQ(s.ok(), true);
        s = db_impl->Get(ro, kvs[idx].first, &value);
        ASSERT_EQ(s.ok(), true);
        s = db_impl->Put(wo, kvs[idx].first, new_values[idx]);
        ASSERT_EQ(s.ok(), true);
        s = db_impl->Get(ro, kvs[idx].first, &value);
        ASSERT_EQ(s.ok(), true);
        ASSERT_EQ(value, new_values[idx].ToString());

        db_impl->entry_cache->Erase(kvs[idx].first);
        int size = db_impl->entry_cache->Cache()->GetShardWriteBatchSize(kvs[idx].first);
        cout << "iter " << j << ": " << "WriteBatchSize: " << size << endl;
        ASSERT_LE(size, 10);
    }
}

} // namespace leveldb

int main(int argc, char** argv) { return leveldb::test::RunAllTests(); }