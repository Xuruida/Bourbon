import os
import sys

from os.path import join
basedir = "/home/kvgroup/xrd/learned_index/bourbon"
ROOT = basedir + "/Bourbon/evaluation-xrd"

LAT_FCTR = 10000*1000*1000
OPS_FCTR = 10000*1000*1000*1000

ycsb_dir = "/home/kvgroup/xrd/learned_index/bourbon/dataset/ycsb"

workload = "r0.5_w0.5"
linenum = "20232277"
opnum = "20000000"
distribution = "zipfian"

def parse_kv(s: str, key: str):
    if s.find(key) != -1:
        t = s.split("=")
        t[0], t[1] = t[0].strip(), t[1].strip()
        print("Parsed: ", t[0], t[1])
        return t[1]
    return None

def parse_workload():
    f = open(join(ycsb_dir, "workloads", "myWorkload.wl"), "r")

    global workload
    global linenum
    global opnum
    global distribution

    read_p = ""
    update_p = ""
    scan_p = ""
    insert_p = ""

    for line in f:
        line = line.strip()
        if len(line) == 0 or line[0] == '#':
            continue
        ln = parse_kv(line, "recordcount")
        if ln is not None:
            linenum = ln

        opn = parse_kv(line, "operationcount")
        if opn is not None:
            opnum = opn
        
        dis = parse_kv(line, "requestdistribution")
        if dis is not None:
            distribution = dis
        
        r_p = parse_kv(line, "readproportion")
        if r_p is not None:
            read_p = r_p
        
        u_p = parse_kv(line, "updateproportion")
        if u_p is not None:
            update_p = u_p

        s_p = parse_kv(line, "scanproportion")
        if s_p is not None:
            scan_p = s_p
        
        i_p = parse_kv(line, "insertproportion")
        if i_p is not None:
            insert_p = i_p

    opnum = int(opnum)
    linenum = int(linenum)
    workload = "r{}_w{}".format(read_p, update_p)
    print(read_p, update_p, scan_p, insert_p)
    print(workload, distribution, linenum, opnum)

def read_file(filename):
    lines = []
    with open(filename, 'r') as f:
        for line in f:
            if line.startswith("Timer 13 MEAN"):
                lines.append(line)

    line = lines[-1]
    time = int(line.split(",")[0].split(":")[1])
    return time

def read_file_x(filename, x):
    lines = []
    with open(filename, 'r') as f:
        for line in f:
            if line.startswith("Timer {} MEAN".format(x)):
                lines.append(line)

    line = lines[-1]
    time = int(line.split(",")[0].split(":")[1])
    return time

def dataset():
    print("Dataset Distibution:\n")
    datasets = ['linear64M', 'segmented1p64M', 'segmented10p64M', 'normal64M', 'ar', 'osm']
    for d in datasets:
        baseline = read_file(join(ROOT, "{}_baseline.txt".format(d)))
        llsm_f = read_file(join(ROOT, "{}_llsm.txt".format(d)))
        llsm_l = read_file(join(ROOT, "{}_llsm_level.txt".format(d)))
        print("{} baseline latency: {:.2f} microseconds".format(d, baseline/LAT_FCTR))
        print("{} llsm (file) latency: {:.2f} microseconds".format(d, llsm_f/LAT_FCTR))
        print("{} llsm (level) latency: {:.2f} microseconds".format(d, llsm_l/LAT_FCTR))
        print("")


def load_order():
    print("Load Order:\n")
    datasets = ['ar', 'osm']
    for d in datasets:
        seq_base = read_file(join(ROOT, "{}_baseline_seqload.txt".format(d)))
        seq_llsm = read_file(join(ROOT, "{}_llsm_seqload.txt".format(d)))
        rdm_base = read_file(join(ROOT, "{}_baseline_rdmload.txt".format(d)))
        rdm_llsm = read_file(join(ROOT, "{}_llsm_rdmload.txt").format(d))
        print("{} baseline seq load latency: {:.2f} microseconds".format(d, seq_base/LAT_FCTR))
        print("{} llsm seq load latency: {:.2f} microseconds".format(d, seq_llsm/LAT_FCTR))
        print("{} baseline random load latency: {:.2f} microseconds".format(d, rdm_base/LAT_FCTR))
        print("{} llsm random load latency: {:.2f} microseconds".format(d, rdm_llsm/LAT_FCTR))
        print("")


def req_dist():
    print("Request Distribution:\n")
    # datasets = ['ar', 'osm']
    # distributions = ['uniform', 'zipfian', 'sequential', 'hotspot', 'latest', 'exponential']
    datasets = ['osm']
    distributions = ['zipfian']
    for dist in distributions:
        for dat in datasets:
            print("======== Total average latency: =======")
            base = read_file(join(ROOT, "{}_baseline_{}.txt".format(dat, dist)))
            llsm = read_file(join(ROOT, "{}_llsm_{}.txt".format(dat, dist)))
            hal = read_file(join(ROOT, "{}_hal_{}.txt".format(dat, dist)))
            print("{} baseline under {} latency: {:.5f} microseconds".format(dat, dist, base/opnum/1000))
            print("{} llsm under {} latency: {:.5f} microseconds".format(dat, dist, llsm/opnum/1000))
            print("{} hal under {} latency: {:.5f} microseconds".format(dat, dist, hal/opnum/1000))
            print("baseline / llsm = {:.5f}".format(base / llsm))
            print("llsm / hal = {:.5f}".format(llsm / hal))

            print("======== Get latency =======")
            base = read_file_x(join(ROOT, "{}_baseline_{}.txt".format(dat, dist)), 4)
            llsm = read_file_x(join(ROOT, "{}_llsm_{}.txt".format(dat, dist)), 4)
            hal = read_file_x(join(ROOT, "{}_hal_{}.txt".format(dat, dist)), 4)
            print("{} baseline under {} latency: {:.5f} microseconds".format(dat, dist, base/opnum/1000))
            print("{} llsm under {} latency: {:.5f} microseconds".format(dat, dist, llsm/opnum/1000))
            print("{} hal under {} latency: {:.5f} microseconds".format(dat, dist, hal/opnum/1000))
            print("baseline / llsm = {:.5f}".format(base / llsm))
            print("llsm / hal = {:.5f}".format(llsm / hal))

            print("")


def ycsb():
    print("YCSB:\n")
    # workloads = ['a', 'b', 'c', 'd', 'f']
    # datasets = ['ycsb', 'ar', 'osm']
    workloads = ['read0.3_write0.7']
    datasets = ['osm']
    # prefix = [10, 33, 20]
    prefix = ['']
    for w in workloads:
        for (d, p) in zip(datasets, prefix):
            base = read_file(join(ROOT, "{}_baseline_ycsb_{}{}.txt".format(d, w, p)))
            llsm = read_file(join(ROOT, "{}_llsm_ycsb_{}{}.txt".format(d, w, p)))
            print("{} baseline on workload {} throughput: {:.2f} kops/sec".format(d, w, OPS_FCTR/base))
            print("{} llsm on workload {} throughput: {:.2f} kops/sec".format(d, w, OPS_FCTR/llsm))
            print("baseline / llsm = {:.2f}".format(base / llsm))
            print("")


def sosd():
    print("SOSD:\n")
    datasets = ['books_200M', 'fb_200M', 'lognormal_200M', 'normal_200M',
                'uniform_dense_200M', 'uniform_sparse_200M']
    for d in datasets:
        base = read_file(join(ROOT, "sosd_{}_baseline.txt".format(d)))
        llsm = read_file(join(ROOT, "sosd_{}_llsm.txt".format(d)))
        print("{} baseline latency: {:.2f} microseconds".format(d, base/LAT_FCTR))
        print("{} llsm latency: {:.2f} microseconds".format(d, llsm/LAT_FCTR))
        print("baseline / llsm = {:.2f}".format(base / llsm))
        print("")


def main():
    if len(sys.argv) != 2:
        print("Usage: prog expr_num \\in [1-5]")
    parse_workload()
    expr = int(sys.argv[1])
    if expr == 1:
        dataset()
    elif expr == 2:
        load_order()
    elif expr == 3:
        req_dist()
    elif expr == 4:
        ycsb()
    elif expr == 5:
        sosd()
    print("")


if __name__ == '__main__':
    main()
