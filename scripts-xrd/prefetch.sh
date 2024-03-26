#!/bin/bash

basedir=/home/kvgroup/xrd/learned_index/bourbon
dataset_dir=${basedir}/dataset
database_dir=${basedir}/database
execute_dir=${basedir}/Bourbon/build
scripts_dir=${basedir}/Bourbon/scripts-xrd
eval_log_dir=${basedir}/Bourbon/evaluation-xrd/prefetch_test
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

dist=$distribution

sync; echo 3 | sudo tee /proc/sys/vm/drop_caches
echo "========= config ========="
echo "info: ${workload} ${linenum} ${opnum} ${dist} ${arg_n} ${insert_bound}"
echo "dist trace file: ${dist_dir}/ycsb_${workload}_ordered_run_${dist}_${linenum}_${opnum}_trace.txt"
echo "log output file (Baseline): ${eval_log_dir}/osm_breakdown_ycsb_${workload}_opnum_${opnum}_${dist}.txt"
echo "=========================="

# for wl in r0.5_w0.5_ordered_run_zipfian r0.95_w0.05_ordered_run_zipfian r1_w0_ordered_run_zipfian r0.95_w0_ordered_run_latest r0.5_w0_ordered_run_zipfian; do
for wl in r0.95_w0_ordered_run_latest; do

    baseline_cmd="${execute_dir}/read_cold -f ${dataset_dir}/osm/osm-num${tmp_linenum}.txt -k 16 -v 1024 -d ${database_dir}/testdb-osm-${linenum}-random -m 8 -u -n ${arg_n} -i 2 --change_level_load --insert ${insert_bound} --YCSB ${dist_dir}/ycsb_${wl}_${linenum}_${opnum}_trace.txt"

    no_prefetch="${execute_dir}/read_cold -f ${dataset_dir}/osm/osm-num${tmp_linenum}.txt -k 16 -v 1024 -d ${database_dir}/testdb-osm-${linenum}-random -m 7 -u -n ${arg_n} -i 2 --change_level_load --insert ${insert_bound} --YCSB ${dist_dir}/ycsb_${wl}_${linenum}_${opnum}_trace.txt"

    prefetch="${execute_dir}/read_cold -f ${dataset_dir}/osm/osm-num${tmp_linenum}.txt -k 16 -v 1024 -d ${database_dir}/testdb-osm-${linenum}-random -m 7 -u -n ${arg_n} -i 2 --change_level_load --insert ${insert_bound} --YCSB ${dist_dir}/ycsb_${wl}_${linenum}_${opnum}_trace.txt --hal_mode 16"

    echo ${wl}
    sync; echo 3 | sudo tee /proc/sys/vm/drop_caches
    echo ${baseline_cmd}
    sudo ${baseline_cmd} > ${eval_log_dir}/ycsb_${wl}_baseline.txt

    sync; echo 3 | sudo tee /proc/sys/vm/drop_caches
    echo ${no_prefetch}
    sudo ${no_prefetch} > ${eval_log_dir}/ycsb_${wl}_no_prefetch.txt

    sync; echo 3 | sudo tee /proc/sys/vm/drop_caches
    echo ${prefetch}
    sudo ${prefetch} > ${eval_log_dir}/ycsb_${wl}_prefetch.txt
done