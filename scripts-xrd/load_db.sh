#!/bin/bash

echo "Usage ./load_db.sh <dataset_name>"
echo "dataset_name: osm | ycsb"

basedir=/home/kvgroup/xrd/learned_index/bourbon
dataset_dir=${basedir}/dataset
database_dir=${basedir}/database
execute_dir=${basedir}/Bourbon/build
scripts_dir=${basedir}/Bourbon/scripts-xrd
eval_log_dir=${basedir}/Bourbon/evaluation-xrd
dist_dir=${dataset_dir}/req_dist
cd ${execute_dir}

# OSM
if [[ "$1" == "osm" ]]; then
    echo "dataset_dir: ${dataset_dir}"
    echo "database_dir: ${database_dir}"

    echo "Removing stale database"
    rm -rf ${database_dir}/testdb-osm${linenum}
    rm -rf ${database_dir}/testdb-osm${linenum}-random

    echo "Loading OSM dataset"
    datasetDir=${basedir}/dataset/ycsb
    linenum=$(eval echo $(awk -F'=' '{ if($1~/^recordcount/) print $2}' ${datasetDir}/workloads/myWorkload.wl))

    trace_linenum=500000
    echo "write osm ${linenum}"
    ./read_cold -f ${dataset_dir}/osm/osm-num${trace_linenum}-lat-nodup.txt -k 16 -v 64 -d ${database_dir}/testdb-osm-${linenum} -m 7 -w > ${eval_log_dir}/osm_${linenum}_put.txt
    echo "finish write osm ${linenum}"
    echo "write osm ${linenum} random"
    ./read_cold -f ${dataset_dir}/osm/osm-num${trace_linenum}-lat-nodup.txt -k 16 -v 64 -d ${database_dir}/testdb-osm-${linenum}-random -m 7 -w -l 3 > ${eval_log_dir}/osm_${linenum}_random_put.txt
    echo "finish write osm ${linenum} random"

    echo "copy random database to llsm/baseline"
    rm -rf ${database_dir}/testdb-llsm-osm-${linenum}-random
    rm -rf ${database_dir}/testdb-baseline-osm-${linenum}-random
    cp -r ${database_dir}/testdb-osm-${linenum}-random ${database_dir}/testdb-llsm-osm-${linenum}-random
    cp -r ${database_dir}/testdb-osm-${linenum}-random ${database_dir}/testdb-baseline-osm-${linenum}-random
    

elif [[ "$1" == "ycsb" ]]; then
    echo "ycsb"
fi


# YCSB hashed
# echo "write YCSB hashed"
# ./read_cold -f /home/kvgroup/xrd/ycsb/ycsb_hashed_load_30000000-prcd.txt -k 16 -v 64 -d /home/kvgroup/xrd/learned-leveldb-par/testdb-ycsb-hashed -m 7 -w > ../evaluation-xrd/ycsb_hashed_put.txt
# ./read_cold -f /home/kvgroup/xrd/ycsb/ycsb_hashed_load_30000000-prcd.txt -k 16 -v 64 -d /home/kvgroup/xrd/learned-leveldb-par/testdb-ycsb-hashed -m 7 -w > ../evaluation-xrd/ycsb_hashed_put-1.txt
# ./read_cold -f /home/kvgroup/xrd/ycsb/ycsb_hashed_load_30000000-ordered.txt -k 16 -v 64 -d /home/kvgroup/xrd/learned-leveldb-par/testdb-ycsb-hashed -m 7 -w -l 3 > ../evaluation-xrd/ycsb_hashed_ord_rdm_put.txt
# ./read_cold -f /home/kvgroup/xrd/ycsb/ycsb_hashed_load_30000000-ordered.txt -k 16 -v 64 -d /home/kvgroup/xrd/learned-leveldb-par/testdb-ycsb-hashed -m 7 -w -l 3 > ../evaluation-xrd/ycsb_hashed_ord_rdm_put-1.txt
# ./read_cold -f /home/kvgroup/xrd/ycsb/ycsb_hashed_load_30000000-ordered.txt -k 16 -v 64 -d /home/kvgroup/xrd/learned-leveldb-par/testdb-ycsb-hashed -m 7 -w > ../evaluation-xrd/ycsb_hashed_ord_ord_put.txt
# ./read_cold -f /home/kvgroup/xrd/ycsb/ycsb_hashed_load_30000000-ordered.txt -k 16 -v 64 -d /home/kvgroup/xrd/learned-leveldb-par/testdb-ycsb-hashed -m 7 -w > ../evaluation-xrd/ycsb_hashed_ord_ord_put-1.txt
# echo "finish write YCSB hashed"
