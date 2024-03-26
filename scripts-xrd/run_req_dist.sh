#!/bin/bash

basedir=/home/kvgroup/xrd/learned_index/bourbon
dataset_dir=${basedir}/dataset
database_dir=${basedir}/database
execute_dir=${basedir}/Bourbon/build
scripts_dir=${basedir}/Bourbon/scripts-xrd
eval_log_dir=${basedir}/Bourbon/evaluation-xrd
dist_dir=${dataset_dir}/ycsb
flamegraph_dir=/home/kvgroup/xrd/tools/FlameGraph

cd ${execute_dir}

linenum=$(eval echo $(awk -F'=' '{ if($1~/^recordcount/) print $2}' ${dataset_dir}/ycsb/workloads/myWorkload.wl))
opnum=$(eval echo $(awk -F'=' '{ if($1~/^operationcount/) print $2}' ${dataset_dir}/ycsb/workloads/myWorkload.wl))
distribution=$(eval echo $(awk -F'=' '{ if($1~/^requestdistribution/) print $2}' ${dataset_dir}/ycsb/workloads/myWorkload.wl))

readproportion=$(eval echo $(awk -F'=' '{ if($1~/^readproportion/) print $2}' ${dataset_dir}/ycsb/workloads/myWorkload.wl))
updateproportion=$(eval echo $(awk -F'=' '{ if($1~/^updateproportion/) print $2}' ${dataset_dir}/ycsb/workloads/myWorkload.wl))

workload=r${readproportion}_w${updateproportion}
# osm
tmp_linenum=${linenum}
insert_bound=${linenum}

arg_n=$[$opnum / 1000]

echo $*
# $1 = 1: run without perf
# $1 = 2: run with perf
# $1 = 3: perf analysis (make svg) only
# $1 = 10: result collection only

if [ ! -n "$1" ] ; then
    echo "\$1 = 1: run without perf"
    echo "==== CPU Cycle: ===="
    echo "\$1 = 2: run with perf"
    echo "\$1 = 3: perf analysis (make svg) only"
    echo "\$1 = 4: clean perf data"
    echo "\$1 = 5: for paper"
    echo "\$1 = 6: for all YCSB"
    echo "\$1 = 7: for FAST'20 Facebook (Prefix Dist)"
    echo "==== cache miss ===="
    echo "\$1 = 11: perf cache miss only"
    echo "\$1 = 12: perf analysis (make svg) only (cache miss)"

    echo "==== micro benchmark for cache size ===="
    echo "\$1 = 21: without perf"
    echo "\$1 = 22: with perf"

    echo "==== collect results only ===="
    echo "\$1 = 100: result collection only"
    exit 0
fi

# for t in llsm baseline hal cacheonly; do=

llsm_log_name=osm_llsm_ycsb${workload}_${dist}_${linenum}_${opnum}.txt
baseline_log_name=osm_baseline_ycsb${workload}_${dist}_${linenum}_${opnum}.txt
hal_log_name=osm_hal_ycsb${workload}_${dist}_${linenum}_${opnum}.txt
cacheonly_log_name=osm_cache_only_ycsb${workload}_${dist}_${linenum}_${opnum}.txt

if [[ "$1" == "6" ]] ; then
    echo "Running osm... FOR ALL YCSB A B C D F"
    # for dist in uniform zipfian sequential hotspot latest exponential; do
    
    echo "A: r0.5_w0.5_ordered_run_zipfian"
    echo "B: r0.95_w0.05_ordered_run_zipfian"
    echo "C: r1_w0_ordered_run_zipfian"
    echo "D: r0.95_w0_ordered_run_latest"
    echo "F: r0.5_w0_ordered_run_zipfian"

    for wl in r0.5_w0.5_ordered_run_zipfian r0.95_w0.05_ordered_run_zipfian r1_w0_ordered_run_zipfian r0.95_w0_ordered_run_latest r0.5_w0_ordered_run_zipfian; do
        sync; echo 3 | sudo tee /proc/sys/vm/drop_caches
        echo "========= config ========="
        echo "info: ${workload} ${linenum} ${opnum} ${dist} ${arg_n} ${insert_bound}"
        echo "dist trace file: ${dist_dir}/ycsb_${workload}_ordered_run_${dist}_${linenum}_${opnum}_trace.txt"
        echo "log output file (LLSM): ${eval_log_dir}/osm_llsm_${dist}.txt"
        echo "log output file (Baseline): ${eval_log_dir}/osm_baseline_${dist}.txt"
        echo "=========================="

        llsm_cmd="${execute_dir}/read_cold -f ${dataset_dir}/osm/osm-num${tmp_linenum}.txt -k 16 -v 1024 -d ${database_dir}/testdb-osm-${linenum}-random -m 7 -u -n ${arg_n} -i 5 --change_level_load --insert ${insert_bound} --YCSB ${dist_dir}/ycsb_${wl}_${linenum}_${opnum}_trace.txt"
        baseline_cmd="${execute_dir}/read_cold -f ${dataset_dir}/osm/osm-num${tmp_linenum}.txt -k 16 -v 1024 -d ${database_dir}/testdb-osm-${linenum}-random -m 8 -u -n ${arg_n} -i 5 --change_level_load --insert ${insert_bound} --YCSB ${dist_dir}/ycsb_${wl}_${linenum}_${opnum}_trace.txt"
        hal_cmd="${execute_dir}/read_cold -f ${dataset_dir}/osm/osm-num${tmp_linenum}.txt -k 16 -v 1024 -d ${database_dir}/testdb-osm-${linenum}-random -m 7 -u -n ${arg_n} -i 5 --change_level_load --insert ${insert_bound} --YCSB ${dist_dir}/ycsb_${wl}_${linenum}_${opnum}_trace.txt --hal_mode 24 --hal_cache_size 512"
        cacheonly_cmd="${execute_dir}/read_cold -f ${dataset_dir}/osm/osm-num${tmp_linenum}.txt -k 16 -v 1024 -d ${database_dir}/testdb-osm-${linenum}-random -m 8 -u -n ${arg_n} -i 5 --change_level_load --insert ${insert_bound} --YCSB ${dist_dir}/ycsb_${wl}_${linenum}_${opnum}_trace.txt --hal_mode 8 --hal_cache_size 512"

        llsm_log_name=osm_llsm_ycsb_${wl}_${linenum}_${opnum}.txt
        baseline_log_name=osm_baseline_ycsb_${wl}_${linenum}_${opnum}.txt
        hal_log_name=osm_hal_ycsb_${wl}_${linenum}_${opnum}.txt
        cacheonly_log_name=osm_cache_only_ycsb_${wl}_${linenum}_${opnum}.txt

        # ./read_cold -f ${dataset_dir}/osm/osm-num${linenum}-lat-nodup.txt -k 16 -v 64 -d ${database_dir}/testdb-osm${linenum}-random -m 7 -u -n 10000 -i 5 --change_level_load --distribution ${dist_dir}/ycsb_c_ordered_run_50m_10m_${dist}_trace.txt > ${eval_log_dir}/osm_llsm_${dist}.txt
        # ./read_cold -f ${dataset_dir}/osm/osm-num${linenum}-lat-nodup.txt -k 16 -v 64 -d ${database_dir}/testdb-osm${linenum}-random -m 7 -u -n 10000 -i 5 --change_level_load --distribution ${dist_dir}/ycsb_c_ordered_run_50m_10m_${dist}_trace.txt > ${eval_log_dir}/osm_llsm_${dist}.txt
        # ./read_cold -f ${dataset_dir}/osm/osm-num${linenum}-lat-nodup.txt -k 16 -v 64 -d ${database_dir}/testdb-osm${linenum}-random -m 8 -u -n 10000 -i 5 --distribution ${dist_dir}/ycsb_c_ordered_run_50m_10m_${dist}_trace.txt > ${eval_log_dir}/osm_baseline_${dist}.txt
        
        echo "========= Commands: ========="
        echo "llsm CMD: ${llsm_cmd}"
        echo "Baseline CMD: ${baseline_cmd}"
        echo "CacheOnly CMD: ${cacheonly_cmd}"
        echo "HaL command: ${hal_cmd}"
        echo "============================="

        sudo ${llsm_cmd} > ${eval_log_dir}/overall/${llsm_log_name}
        sudo ${cacheonly_cmd} > ${eval_log_dir}/overall/${cacheonly_log_name}
        sudo ${hal_cmd} > ${eval_log_dir}/overall/${hal_log_name}
        sudo ${baseline_cmd} > ${eval_log_dir}/overall/${baseline_log_name}
    done

    exit 0
fi

if [[ "$1" == "7" ]] ; then
    echo "Running FAST'20 Facebook (prefix)"

    sync; echo 3 | sudo tee /proc/sys/vm/drop_caches
    echo "========= config ========="
    echo "info: FAST'20 Facebook (prefix)"
    echo "dist trace file: ${dataset_dir}/prefix_dist/prefix_dist_30M_10M_trace.txt"

    llsm_log_name=prefix_dist_llsm_30M_10M.txt
    baseline_log_name=prefix_dist_baseline_30M_10M.txt
    hal_log_name=prefix_dist_hal_30M_10M.txt
    cacheonly_log_name=prefix_dist_cache_only_30M_10M.txt

    echo "log output file (Baseline): ${baseline_log_name}"
    echo "=========================="

    llsm_cmd="${execute_dir}/read_cold -f ${dataset_dir}/osm/osm-num${tmp_linenum}.txt -k 16 -v 1024 -d ${database_dir}/testdb-osm-${linenum}-random -m 7 -u -n ${arg_n} -i 5 --change_level_load --insert ${insert_bound} --YCSB ${dataset_dir}/prefix_dist/prefix_dist_30M_10M_trace.txt"
    baseline_cmd="${execute_dir}/read_cold -f ${dataset_dir}/osm/osm-num${tmp_linenum}.txt -k 16 -v 1024 -d ${database_dir}/testdb-osm-${linenum}-random -m 8 -u -n ${arg_n} -i 5 --change_level_load --insert ${insert_bound} --YCSB ${dataset_dir}/prefix_dist/prefix_dist_30M_10M_trace.txt"
    hal_cmd="${execute_dir}/read_cold -f ${dataset_dir}/osm/osm-num${tmp_linenum}.txt -k 16 -v 1024 -d ${database_dir}/testdb-osm-${linenum}-random -m 7 -u -n ${arg_n} -i 5 --change_level_load --insert ${insert_bound} --YCSB ${dataset_dir}/prefix_dist/prefix_dist_30M_10M_trace.txt --hal_mode 24 --hal_cache_size 512"
    cacheonly_cmd="${execute_dir}/read_cold -f ${dataset_dir}/osm/osm-num${tmp_linenum}.txt -k 16 -v 1024 -d ${database_dir}/testdb-osm-${linenum}-random -m 8 -u -n ${arg_n} -i 5 --change_level_load --insert ${insert_bound} --YCSB ${dataset_dir}/prefix_dist/prefix_dist_30M_10M_trace.txt --hal_mode 8 --hal_cache_size 512"

    echo "========= Commands: ========="
    echo "llsm CMD: ${llsm_cmd}"
    echo "Baseline CMD: ${baseline_cmd}"
    echo "CacheOnly CMD: ${cacheonly_cmd}"
    echo "HaL command: ${hal_cmd}"
    echo "============================="

    sudo ${llsm_cmd} > ${eval_log_dir}/overall/${llsm_log_name}
    sudo ${cacheonly_cmd} > ${eval_log_dir}/overall/${cacheonly_log_name}
    sudo ${hal_cmd} > ${eval_log_dir}/overall/${hal_log_name}
    sudo ${baseline_cmd} > ${eval_log_dir}/overall/${baseline_log_name}

    exit 0
fi

if [[ "$1" == "1" ]] || [[ "$1" == "2" ]] || [[ "$1" == "3" ]] || [[ "$1" == "4" ]] || [[ "$1" == "5" ]] || [[ "$1" == "11" ]] || [[ "$1" == "12" ]] ; then
    echo "Running osm..."
    # for dist in uniform zipfian sequential hotspot latest exponential; do
    # A: r0.5_w0.5_ordered_run_zipfian
    # B: r0.95_w0.05_ordered_run_zipfian
    # C: r1_w0_ordered_run_zipfian
    # D: r0.95_w0_ordered_run_latest
    # F: r0.5_w0_ordered_run_zipfian
    dist=${distribution}
    sync; echo 3 | sudo tee /proc/sys/vm/drop_caches
    echo "========= config ========="
    echo "info: ${workload} ${linenum} ${opnum} ${dist} ${arg_n} ${insert_bound}"
    echo "dist trace file: ${dist_dir}/ycsb_${workload}_ordered_run_${dist}_${linenum}_${opnum}_trace.txt"
    echo "log output file (LLSM): ${eval_log_dir}/osm_llsm_${dist}.txt"
    echo "log output file (Baseline): ${eval_log_dir}/osm_baseline_${dist}.txt"
    echo "=========================="

    llsm_cmd="${execute_dir}/read_cold -f ${dataset_dir}/osm/osm-num${tmp_linenum}.txt -k 16 -v 1024 -d ${database_dir}/testdb-osm-${linenum}-random -m 7 -u -n ${arg_n} -i 5 --change_level_load --insert ${insert_bound} --YCSB ${dist_dir}/ycsb_${workload}_ordered_run_${dist}_${linenum}_${opnum}_trace.txt"
    baseline_cmd="${execute_dir}/read_cold -f ${dataset_dir}/osm/osm-num${tmp_linenum}.txt -k 16 -v 1024 -d ${database_dir}/testdb-osm-${linenum}-random -m 8 -u -n ${arg_n} -i 5 --change_level_load --insert ${insert_bound} --YCSB ${dist_dir}/ycsb_${workload}_ordered_run_${dist}_${linenum}_${opnum}_trace.txt"
    hal_cmd="${execute_dir}/read_cold -f ${dataset_dir}/osm/osm-num${tmp_linenum}.txt -k 16 -v 1024 -d ${database_dir}/testdb-osm-${linenum}-random -m 7 -u -n ${arg_n} -i 5 --change_level_load --insert ${insert_bound} --YCSB ${dist_dir}/ycsb_${workload}_ordered_run_${dist}_${linenum}_${opnum}_trace.txt --hal_mode 24 --hal_cache_size 512"
    cacheonly_cmd="${execute_dir}/read_cold -f ${dataset_dir}/osm/osm-num${tmp_linenum}.txt -k 16 -v 1024 -d ${database_dir}/testdb-osm-${linenum}-random -m 8 -u -n ${arg_n} -i 5 --change_level_load --insert ${insert_bound} --YCSB ${dist_dir}/ycsb_${workload}_ordered_run_${dist}_${linenum}_${opnum}_trace.txt --hal_mode 8 --hal_cache_size 512"


    # ./read_cold -f ${dataset_dir}/osm/osm-num${linenum}-lat-nodup.txt -k 16 -v 64 -d ${database_dir}/testdb-osm${linenum}-random -m 7 -u -n 10000 -i 5 --change_level_load --distribution ${dist_dir}/ycsb_c_ordered_run_50m_10m_${dist}_trace.txt > ${eval_log_dir}/osm_llsm_${dist}.txt
    # ./read_cold -f ${dataset_dir}/osm/osm-num${linenum}-lat-nodup.txt -k 16 -v 64 -d ${database_dir}/testdb-osm${linenum}-random -m 7 -u -n 10000 -i 5 --change_level_load --distribution ${dist_dir}/ycsb_c_ordered_run_50m_10m_${dist}_trace.txt > ${eval_log_dir}/osm_llsm_${dist}.txt
    # ./read_cold -f ${dataset_dir}/osm/osm-num${linenum}-lat-nodup.txt -k 16 -v 64 -d ${database_dir}/testdb-osm${linenum}-random -m 8 -u -n 10000 -i 5 --distribution ${dist_dir}/ycsb_c_ordered_run_50m_10m_${dist}_trace.txt > ${eval_log_dir}/osm_baseline_${dist}.txt
    
    echo "========= Commands: ========="
    echo "llsm CMD: ${llsm_cmd}"
    echo "Baseline CMD: ${baseline_cmd}"
    echo "CacheOnly CMD: ${cacheonly_cmd}"
    echo "HaL command: ${hal_cmd}"
    echo "============================="

    if [[ "$1" == "11" ]] || [[ "$1" == "12" ]] ; then
        llsm_prefix=osm-llsm-cachemiss-num${linenum}-random-${dist}-perf
        baseline_prefix=osm-baseline-cachemiss-num${linenum}-random-${dist}-perf
        if [[ "$1" == "11" ]] ; then
            sudo ${llsm_cmd} > ${eval_log_dir}/osm_llsm_${dist}.txt
            sudo perf record -e cache-misses -F 499 --call-graph dwarf,65528 -o ${eval_log_dir}/perf/${llsm_prefix}.data ${llsm_cmd} > ${eval_log_dir}/osm_llsm_${dist}.txt
            sudo perf record -e cache-misses -F 499 --call-graph dwarf,65528 -o ${eval_log_dir}/perf/${baseline_prefix}.data ${baseline_cmd} > ${eval_log_dir}/osm_baseline_${dist}.txt
        fi

        # llsm
        sudo perf script -i ${eval_log_dir}/perf/${llsm_prefix}.data &> ${eval_log_dir}/perf/${llsm_prefix}.unfold
        ${flamegraph_dir}/stackcollapse-perf.pl ${eval_log_dir}/perf/${llsm_prefix}.unfold &> ${eval_log_dir}/perf/${llsm_prefix}.folded
        ${flamegraph_dir}/flamegraph.pl ${eval_log_dir}/perf/${llsm_prefix}.folded > ${eval_log_dir}/perf/svg/${llsm_prefix}.svg
        echo "FlameGraph SVG: ${eval_log_dir}/perf/eval/${llsm_prefix}.svg"

        # baseline
        sudo perf script -i ${eval_log_dir}/perf/${baseline_prefix}.data &> ${eval_log_dir}/perf/${baseline_prefix}.unfold
        ${flamegraph_dir}/stackcollapse-perf.pl ${eval_log_dir}/perf/${baseline_prefix}.unfold &> ${eval_log_dir}/perf/${baseline_prefix}.folded
        ${flamegraph_dir}/flamegraph.pl ${eval_log_dir}/perf/${baseline_prefix}.folded > ${eval_log_dir}/perf/svg/${baseline_prefix}.svg
        echo "FlameGraph SVG: ${eval_log_dir}/perf/eval/${baseline_prefix}.svg"
    fi

    if [[ "$1" == "1" ]]; then
        # sudo ${llsm_cmd} > ${eval_log_dir}/osm_llsm_${dist}.txt
        sudo ${llsm_cmd} > ${eval_log_dir}/osm_llsm_${dist}.txt
        # sudo ${hal_cmd} > ${eval_log_dir}/osm_hal_${dist}.txt
        sudo ${hal_cmd} > ${eval_log_dir}/osm_hal_${dist}.txt
        sudo ${baseline_cmd} > ${eval_log_dir}/osm_baseline_${dist}.txt
    fi

    if [[ "$1" == "5" ]]; then

        # echo "Removing mix db"
        # sudo rm -rf ${database_dir}/testdb-osm-${linenum}-random_mix
        # echo "Copying mix db"
        # sudo cp -r ${database_dir}/testdb-osm-${linenum}-random ${database_dir}/testdb-osm-${linenum}-random_mix
        sudo ${llsm_cmd} > ${eval_log_dir}/${llsm_log_name}

        # echo "Removing mix db"
        # sudo rm -rf ${database_dir}/testdb-osm-${linenum}-random_mix
        # echo "Copying mix db"
        # sudo cp -r ${database_dir}/testdb-osm-${linenum}-random ${database_dir}/testdb-osm-${linenum}-random_mix
        sudo ${cacheonly_cmd} > ${eval_log_dir}/${cacheonly_log_name}

        # echo "Removing mix db"
        # sudo rm -rf ${database_dir}/testdb-osm-${linenum}-random_mix
        # echo "Copying mix db"
        # sudo cp -r ${database_dir}/testdb-osm-${linenum}-random ${database_dir}/testdb-osm-${linenum}-random_mix
        sudo ${hal_cmd} > ${eval_log_dir}/${hal_log_name}

        # echo "Removing mix db"
        # sudo rm -rf ${database_dir}/testdb-osm-${linenum}-random_mix
        # echo "Copying mix db"
        # sudo cp -r ${database_dir}/testdb-osm-${linenum}-random ${database_dir}/testdb-osm-${linenum}-random_mix
        sudo ${baseline_cmd} > ${eval_log_dir}/${baseline_log_name}
    fi

    if [[ "$1" == "4" ]]; then
        sudo rm -f ${eval_log_dir}/perf/${llsm_prefix}.data
        sudo rm -f ${eval_log_dir}/perf/${baseline_prefix}.data
        sudo rm -f ${eval_log_dir}/perf/${hal_prefix}.data
        echo "clean up done"
        exit
    fi

    if [[ "$1" == "2" ]] || [[ "$1" == "3" ]]; then
        llsm_prefix=osm-llsm-num${linenum}-random-${dist}-perf
        baseline_prefix=osm-baseline-num${linenum}-random-${dist}-perf
        hal_prefix=osm-hal-num${linenum}-random-${dist}-perf
        if [[ "$1" == "2" ]]; then

            # echo "LLSM 1..."
            # sudo ${llsm_cmd} > ${eval_log_dir}/osm_llsm_${dist}.txt
            echo "LLSM Perf..."
            sudo perf record -e cycles -F 499 --call-graph dwarf,65528 -o ${eval_log_dir}/perf/${llsm_prefix}.data ${llsm_cmd} > ${eval_log_dir}/osm_llsm_${dist}.txt

            # echo "hal 1..."
            # sudo ${hal_cmd} > ${eval_log_dir}/osm_hal_${dist}.txt
            echo "hal perf..."
            sudo perf record -e cycles -F 499 --call-graph dwarf,65528 -o ${eval_log_dir}/perf/${hal_prefix}.data ${hal_cmd} > ${eval_log_dir}/osm_hal_${dist}.txt

            echo "baseline perf..."
            sudo perf record -e cycles -F 499 --call-graph dwarf,65528 -o ${eval_log_dir}/perf/${baseline_prefix}.data ${baseline_cmd} > ${eval_log_dir}/osm_baseline_${dist}.txt
        fi

        # llsm
        # if [ -f "${eval_log_dir}/perf/${llsm_prefix}.data" ];then
            sudo perf script -i ${eval_log_dir}/perf/${llsm_prefix}.data &> ${eval_log_dir}/perf/${llsm_prefix}.unfold
        # fi
        # sudo rm -f ${eval_log_dir}/perf/${llsm_prefix}.data
        ${flamegraph_dir}/stackcollapse-perf.pl ${eval_log_dir}/perf/${llsm_prefix}.unfold &> ${eval_log_dir}/perf/${llsm_prefix}.folded
        ${flamegraph_dir}/flamegraph.pl ${eval_log_dir}/perf/${llsm_prefix}.folded > ${eval_log_dir}/perf/svg/${llsm_prefix}.svg
        echo "FlameGraph SVG: ${eval_log_dir}/perf/eval/${llsm_prefix}.svg"

        # baseline
        # if [ -f "${eval_log_dir}/perf/${baseline_prefix}.data" ];then
            sudo perf script -i ${eval_log_dir}/perf/${baseline_prefix}.data &> ${eval_log_dir}/perf/${baseline_prefix}.unfold
        # fi
        # sudo rm -f ${eval_log_dir}/perf/${baseline_prefix}.data
        ${flamegraph_dir}/stackcollapse-perf.pl ${eval_log_dir}/perf/${baseline_prefix}.unfold &> ${eval_log_dir}/perf/${baseline_prefix}.folded
        ${flamegraph_dir}/flamegraph.pl ${eval_log_dir}/perf/${baseline_prefix}.folded > ${eval_log_dir}/perf/svg/${baseline_prefix}.svg
        echo "FlameGraph SVG: ${eval_log_dir}/perf/eval/${baseline_prefix}.svg"

        # hal
        # if [ -f "${eval_log_dir}/perf/${hal_prefix}.data" ];then
            sudo perf script -i ${eval_log_dir}/perf/${hal_prefix}.data &> ${eval_log_dir}/perf/${hal_prefix}.unfold
        # fi
        # sudo rm -f ${eval_log_dir}/perf/${hal_prefix}.data
        ${flamegraph_dir}/stackcollapse-perf.pl ${eval_log_dir}/perf/${hal_prefix}.unfold &> ${eval_log_dir}/perf/${hal_prefix}.folded
        ${flamegraph_dir}/flamegraph.pl ${eval_log_dir}/perf/${hal_prefix}.folded > ${eval_log_dir}/perf/svg/${hal_prefix}.svg
        echo "FlameGraph SVG: ${eval_log_dir}/perf/eval/${hal_prefix}.svg"
    fi
    
    echo "log file: ${eval_log_dir}/osm_baseline_${dist}.txt"
fi

if [[ "$1" == "21" ]] || [[ "$1" == "22" ]] || [[ "$1" == "99" ]]; then
    echo "Running osm..."
    # for dist in uniform zipfian sequential hotspot latest exponential; do
    for dist in zipfian; do
        sync; echo 3 | sudo tee /proc/sys/vm/drop_caches
        echo "========= config ========="
        echo "info: ${workload} ${linenum} ${opnum} ${dist} ${arg_n} ${insert_bound}"
        echo "dist trace file: ${dist_dir}/ycsb_${workload}_ordered_run_${dist}_${linenum}_${opnum}_trace.txt"
        echo "log output file (LLSM): ${eval_log_dir}/osm_llsm_${dist}.txt"
        echo "log output file (Baseline): ${eval_log_dir}/osm_baseline_${dist}.txt"
        echo "=========================="

        llsm_cmd="${execute_dir}/read_cold -f ${dataset_dir}/osm/osm-num${tmp_linenum}.txt -k 16 -v 1024 -d ${database_dir}/testdb-osm-${linenum}-random -m 7 -u -n ${arg_n} -i 5 --change_level_load --insert ${insert_bound} --YCSB ${dist_dir}/ycsb_${workload}_ordered_run_${dist}_${linenum}_${opnum}_trace.txt"
        baseline_cmd="${execute_dir}/read_cold -f ${dataset_dir}/osm/osm-num${tmp_linenum}.txt -k 16 -v 1024 -d ${database_dir}/testdb-osm-${linenum}-random -m 8 -u -n ${arg_n} -i 5 --change_level_load --insert ${insert_bound} --YCSB ${dist_dir}/ycsb_${workload}_ordered_run_${dist}_${linenum}_${opnum}_trace.txt"
        hal_cmd="${execute_dir}/read_cold -f ${dataset_dir}/osm/osm-num${tmp_linenum}.txt -k 16 -v 1024 -d ${database_dir}/testdb-osm-${linenum}-random -m 7 -u -n ${arg_n} -i 5 --change_level_load --insert ${insert_bound} --YCSB ${dist_dir}/ycsb_${workload}_ordered_run_${dist}_${linenum}_${opnum}_trace.txt --hal_mode 24"
        


        # ./read_cold -f ${dataset_dir}/osm/osm-num${linenum}-lat-nodup.txt -k 16 -v 64 -d ${database_dir}/testdb-osm${linenum}-random -m 7 -u -n 10000 -i 5 --change_level_load --distribution ${dist_dir}/ycsb_c_ordered_run_50m_10m_${dist}_trace.txt > ${eval_log_dir}/osm_llsm_${dist}.txt
        # ./read_cold -f ${dataset_dir}/osm/osm-num${linenum}-lat-nodup.txt -k 16 -v 64 -d ${database_dir}/testdb-osm${linenum}-random -m 7 -u -n 10000 -i 5 --change_level_load --distribution ${dist_dir}/ycsb_c_ordered_run_50m_10m_${dist}_trace.txt > ${eval_log_dir}/osm_llsm_${dist}.txt
        # ./read_cold -f ${dataset_dir}/osm/osm-num${linenum}-lat-nodup.txt -k 16 -v 64 -d ${database_dir}/testdb-osm${linenum}-random -m 8 -u -n 10000 -i 5 --distribution ${dist_dir}/ycsb_c_ordered_run_50m_10m_${dist}_trace.txt > ${eval_log_dir}/osm_baseline_${dist}.txt
        
        echo "========= Commands: ========="
        echo "OSM CMD: ${llsm_cmd}"
        echo "Baseline CMD: ${baseline_cmd}"
        echo "HaL command: ${hal_cmd}"
        for sz in 64 128 256 512 1024; do
            hal_cmd_sz="${hal_cmd} --hal_cache_size ${sz}"
            echo "${hal_cmd_sz}"
        done
        echo "============================="

        if [[ "$1" == "21" ]]; then
            sudo ${llsm_cmd} > ${eval_log_dir}/osm_llsm_${dist}.txt
            sudo ${baseline_cmd} > ${eval_log_dir}/osm_baseline_${dist}.txt

            for sz in 32 64 128 256 512 1024; do
                hal_cmd_sz="${hal_cmd} --hal_cache_size ${sz}"
                sudo ${hal_cmd_sz} > ${eval_log_dir}/osm_hal_${dist}_${sz}.txt
            done
        fi

        if [[ "$1" == "99" ]]; then
            for sz in 32 64 128 256 512 1024; do
                hal_cmd_sz="${hal_cmd} --hal_cache_size ${sz}"
                sudo ${hal_cmd_sz} > ${eval_log_dir}/osm_hal_${dist}_${sz}.txt
            done
        fi

        echo "log file: ${eval_log_dir}/osm_baseline_${dist}.txt"

        echo "Running collecting res..."
        python3 ${scripts_dir}/collect_results.py 6 > ${eval_log_dir}/expr_request_dist.txt
        cat ${eval_log_dir}/expr_request_dist.txt
    done
    exit 0
fi


echo "Running collecting res..."
python3 ${scripts_dir}/collect_results.py 3 > ${eval_log_dir}/expr_request_dist.txt
cat ${eval_log_dir}/expr_request_dist.txt
