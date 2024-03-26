from breakdown_eval import outputTimers
from os.path import join

evalDir = "/home/kvgroup/xrd/learned_index/bourbon/Bourbon/evaluation-xrd/prefetch_test/"

if __name__ == '__main__':
    workloads = {
        "A": "ycsb_r0.5_w0.5_ordered_run_zipfian",
        "B": "ycsb_r0.95_w0.05_ordered_run_zipfian",
        "C": "ycsb_r1_w0_ordered_run_zipfian",
        "D": "ycsb_r0.95_w0_ordered_run_latest",
        "F": "ycsb_r0.5_w0_ordered_run_zipfian",
    }
    res = {
        'baseline': [],
        'no_prefetch': [],
        'prefetch': []
    }
    for wl in workloads:
        files = workloads[wl]
        for x in ['baseline', 'no_prefetch', 'prefetch']:
            path = join(evalDir, files + "_" + x + ".txt")
            print("===================================")
            ts = outputTimers(path)
            print("===================================\n\n")
            res[x].append(ts[2]/10000000)
    
    for wl in workloads:
        print(res)

#    for x in ['ycsb_c_10M_baseline.txt', 'ycsb_c_10M_no_prefetch.txt', 'ycsb_c_10M_prefetch.txt']:
#         path = join(evalDir, x)
#         print("===================================")
#         ts = outputTimers(path)
#         print("===================================\n\n")
