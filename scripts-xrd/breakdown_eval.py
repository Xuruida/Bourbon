"""
Internal
- Timer 0: file lookup time within one level, version_set.cc
- Timer 1: file reading time, table_cache.cc
- Timer 2: file model inference time, table_cache.cc
- Timer 3: key search time in file - first search
- Timer 5: key search time in file - rest time
- TImer 12: Value reading time
- Timer 14: value read from memtable or immtable
- Timer 15: FilteredLookup time

- Timer 6: Total key search time given files
- Timer 13 is the total time, which is the time we report.
- Timer 4 is the total time for all get requests.
- Timer 10 is the total time for all put requests.
- Timer 7 is the total compaction time.
- Timer 11 is the total file model learning time.
- Timer 8 is the total level learning time
- timer 9: Total fresh write time (db load)
- timer 16: time to compact memtable
"""

import proplot as pplt
import numpy as np
import pandas as pd
import os

from cycler import cycler

# 自定义填充图案列表
hatches = ['/', '\\', '|', '-', '+', 'x', 'o', 'O', '.', '*']

keyWords = [
    # "NOP",
    "File Lookup",
    "File Reading",
    "Model Inference / Seek [IB]",
    "Key Search (First)",
    "Total Get Time",
    "Key Search (Rest)",
    "Total Key Search",
    "Total Compaction",
    "Total Level Learning",
    "Total Fresh Write (load)",
    "Total Put Time",
    "Total File Model Learning",
    "Value Reading",
    "Total Time",
    "Value Read From Mem and Imm",
    "Filtered Lookup [FB]",
    "Memtable Compaction Time (Flush)",
    "NOP",
    "NOP",
    "NOP",
    "NOP",
    "NOP",
    "NOP",
]


def getKey(x):
    return "Timer {}".format(x)

opNum = 10000000

def outputTimers(filename):
    f = open(filename, "r")
    print(os.path.basename(filename))
    lines = f.readlines()
    start = 0
    for i, l in enumerate(lines):
        if l.startswith("Data Without the First Item"):
            print(i)
            start = i + 1

    timers = lines[start:start+20]
    timers = [int(x.split(" ")[3][:-1]) for x in timers]
    for i, t in enumerate(timers):
        print("{:2}: {:35}, {}".format(i, keyWords[i], t / opNum))
    return timers

def my_draw(ts):
    # Find Table             (0)
    # Read IB + FB          (1)
    # Search IB             (2)
    # Search FB             (15)
    # Search InBlock        (3 + 5)
    # Value Read            (12)
    # Other                 (Total - sum)
    
    keys = ["Find Table", "Search IB", "Search FB", "Search DB", "Read Value", "Other"]

    fig = pplt.figure(figsize=(4, 3))
    ax = fig.subplot(xlabel='key', ylabel='Latency (us)')
    
    total = 5.400
    ts = np.array([ts[0], ts[2], ts[15], ts[3] + ts[5], ts[12]])

    ts = ts / opNum / 1000
    
    print(np.sum(ts))
    other = total - np.sum(ts)

    ts = np.append(ts, other)
    print(ts)

    # data = pd.DataFrame(ts, columns=pd.Index(np.arange(1, len(keys) + 1), name='Type'), index=pd.Index(['OSM'], name='Key'))
    ax.legend(ncols=1, loc='ur')
    ks = ['test']

    i = 0
    wd = 0.3
    tmp = 0
    for i in range(len(ts)):
        ax.bar(ks, ts[i], edgecolor='black', bottom=np.array([tmp]), legend='ul', hatch=hatches[i], color='white', label=keys[i])
        tmp += ts[i]
    ax.format(xlim=(0, 7))
    fig.save('LevelDBReadBreakdown.pdf')
    fig.save('LevelDBReadBreakdown.png')

if __name__ == "__main__":
    filename = "../evaluation-xrd/osm_breakdown_ycsb_r1_w0_opnum_10000000_zipfian.txt"
    ts = outputTimers(filename)
    my_draw(ts)

