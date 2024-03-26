import os
import sys
import numpy as np
import proplot as pplt
from matplotlib.ticker import FuncFormatter

from os.path import join
basedir = "/home/kvgroup/xrd/learned_index/bourbon/evaluation-xrd"

LAT_FCTR = 10000*1000*1000
OPS_FCTR = 10000*1000*1000*1000

log_path = "/home/kvgroup/xrd/learned_index/bourbon/Bourbon/evaluation-xrd/overall/prefix_dist_baseline_30M_10M.txt"
workload = "r0.5_w0.5"
linenum = "20232277"
opnum = "20000000"
distribution = "zipfian"

def read_file_sst(filename):
    lines = []
    with open(filename, 'r') as f:
        for line in f:
            # print(line)
            if line.startswith("FileStats "):
                lines.append(line)

    levels = []
    for i in range(7):
        levels.append(dict())
    # FileStats 6412 0 57734103040 112081575936 17193 9014164 2417396 1
    for l in lines:
        ls = list(map(int, l.split()[1:]))
        id = ls[0]
        lvl = ls[1]
        count = ls[4] + ls[5]
        if count > 0:
            levels[lvl][id] = count
    # [id 1, pos 5, neg 6, size 7]
    for i in range(len(levels)):
        res = []
        for k in sorted(levels[i].keys()):
            res.append(levels[i][k])
        levels[i] = res

    return levels

def main():
    data = read_file_sst(log_path)
    print(data)
    fig = pplt.figure(figsize=(4, 2.5))
    ax = fig.subplot(xlabel='SSTable ID', ylabel='SSTable Access Count')
    ax.format(xformatter='sci', yformatter='sci', xlim = (1, 600), yscale='log', xscale='log', ytickminor=False, xlocator=[1, 10, 100])

    def custom_formatter(x, pos):
        if x == 1:
            return r"${10}^" + r"{" + str(int(np.log10(x))) + r"}$"
        elif x >= 10:
            return r"${10}^" + r"{" + str(int(np.log10(x))) + r"}$"
        elif x > 0 and x < 1:
            return r"${10}^" + r"{" + str(int(np.log10(x))) + r"}$"
        else:
            return ""

    def x_fomat(x, pos):
        return str(int(x))
        
    ax.yaxis.set_major_formatter(FuncFormatter(custom_formatter))
    ax.xaxis.set_major_formatter(FuncFormatter(x_fomat))

    if len(data[-1]) == 0:
        data = data[:-1]


    
    d = [x for i in data for x in i]
    xs = np.linspace(1, len(d), len(d))
    ax.plot(xs, d, color='black', ls='-', linewidth=1)

    vxs = []
    sum = 0
    for k in data:
        sum = sum + len(k)
        vxs.append(sum)
    
    print(vxs)
    vxs = vxs[:-2]

    for x in vxs:
        ax.axvline(x + 0.5, color='black', ls='--', linewidth=1.5)
    
    # for i in range(len(data)):
    #     y = data[i]
    #     xs = np.linspace(1, len(y), len(y))
    #     xs = xs + sum
    #     sum = sum + len(y)
    #     ax.plot(xs, y, color='black', ls='-')
    
    
    fig.save('figs/prefix_sst_access.png')
    fig.save('figs/prefix_sst_access.pdf')

if __name__ == '__main__':
    main()
