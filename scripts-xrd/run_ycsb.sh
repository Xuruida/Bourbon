#!/bin/bash

basedir=/home/kvgroup/xrd/learned_index/bourbon
dataset_dir=${basedir}/dataset
database_dir=${basedir}/database
execute_dir=${basedir}/Bourbon/build
scripts_dir=${basedir}/Bourbon/scripts-xrd
eval_log_dir=${basedir}/Bourbon/evaluation-xrd
dist_dir=${dataset_dir}/req_dist
flamegraph_dir=/home/kvgroup/xrd/tools/FlameGraph

cd ${execute_dir}

# OSM
# $1 = 1 do all
# $1 = 2 make graph only

echo "osm ycsb"
LINENUM=50000000
if [[ "$1" == "1" ]] || [[ "$1" == "2" ]]; then
    for dist in ycsb_read0.3_write0.7; do
        if [[ "$1" == "1" ]]; then
            sync; echo 3 | sudo tee /proc/sys/vm/drop_caches

            ds_path=${dataset_dir}/osm/osm-num${LINENUM}-lat-nodup.txt
            db_path=${database_dir}/testdb-osm${LINENUM}-random
            tc_path=${dataset_dir}/ycsb/${dist}_ordered_run_${LINENUM}_trace.txt

            bourbon_cmd="./read_cold -f ${ds_path} -k 16 -v 64 -d ${db_path} -m 7 -u --change_level_load --YCSB ${tc_path} -n 10000 -i 5"
            baseline_cmd="./read_cold -f ${ds_path} -k 16 -v 64 -d ${db_path} -m 8 -u --YCSB ${tc_path} -n 10000 -i 5"

            echo $bourbon_cmd
            echo $baseline_cmd

            bourbon_prefix=osm-bourbon-num${LINENUM}-random-${dist}-perf
            baseline_prefix=osm-baseline-num${LINENUM}-random-${dist}-perf

            echo "Running ${dist} Bourbon..."
            sudo perf record -e cycles -F 1000 --call-graph dwarf,65528 -o ${eval_log_dir}/perf/${bourbon_prefix}.data ${bourbon_cmd} > ${eval_log_dir}/osm_llsm_${dist}.txt
            echo "Finished Bourbon"
        
            echo "Running ${dist} WiscKey..."
            sudo perf record -e cycles -F 1000 --call-graph dwarf,65528 -o ${eval_log_dir}/perf/${baseline_prefix}.data ${baseline_cmd} > ${eval_log_dir}/osm_baseline_${dist}.txt
            echo "Finished Baseline"

        fi
        # Bourbon
        sudo perf script -i ${eval_log_dir}/perf/${bourbon_prefix}.data &> ${eval_log_dir}/perf/${bourbon_prefix}.unfold
        ${flamegraph_dir}/stackcollapse-perf.pl ${eval_log_dir}/perf/${bourbon_prefix}.unfold &> ${eval_log_dir}/perf/${bourbon_prefix}.folded
        ${flamegraph_dir}/flamegraph.pl ${eval_log_dir}/perf/${bourbon_prefix}.folded > ${eval_log_dir}/perf/svg/${bourbon_prefix}.svg
        echo "FlameGraph SVG: ${eval_log_dir}/perf/eval/${bourbon_prefix}.svg"

        # baseline
        sudo perf script -i ${eval_log_dir}/perf/${baseline_prefix}.data &> ${eval_log_dir}/perf/${baseline_prefix}.unfold
        ${flamegraph_dir}/stackcollapse-perf.pl ${eval_log_dir}/perf/${baseline_prefix}.unfold &> ${eval_log_dir}/perf/${baseline_prefix}.folded
        ${flamegraph_dir}/flamegraph.pl ${eval_log_dir}/perf/${baseline_prefix}.folded > ${eval_log_dir}/perf/svg/${baseline_prefix}.svg
        echo "FlameGraph SVG: ${eval_log_dir}/perf/eval/${baseline_prefix}.svg"

    done
fi

echo "Running collecting res..."
python3 ${scripts_dir}/collect_results.py 4 > ${eval_log_dir}"/expr_request_ycsb_read0.3_write0.7.txt"
cat ${eval_log_dir}"/expr_request_ycsb_read0.3_write0.7.txt"

# YCSB hashed
# echo "YCSB hashed A B D F"
# LINENUM=30000000
# for dist in ycsb_a ycsb_b ycsb_d ycsb_f; do
#     sync; echo 3 | sudo tee /proc/sys/vm/drop_caches
#     echo "${dist} Bourbon"
#     ./read_cold -f /home/kvgroup/cya/ycsb/ycsb_hashed_load_30000000-prcd.txt \
#         -k 16 -v 64 -d /home/kvgroup/cya/learned-leveldb-par/testdb-ycsb-hashed -m 7 -u --change_level_load \
#         --YCSB /home/kvgroup/cya/ycsb/${dist}_ordered_run_${LINENUM}_trace.txt \
#         --insert 30000000 -n 10000 -i 5 > ../evaluation-cya/ycsb_llsm_${dist}.txt
#     echo "${dist} WiscKey"
#     ./read_cold -f /home/kvgroup/cya/ycsb/ycsb_hashed_load_30000000-prcd.txt \
#         -k 16 -v 64 -d /home/kvgroup/cya/learned-leveldb-par/testdb-ycsb-hashed -m 8 -u \
#         --YCSB /home/kvgroup/cya/ycsb/${dist}_ordered_run_${LINENUM}_trace.txt \
#         --insert 30000000 -n 10000 -i 5 > ../evaluation-cya/ycsb_baseline_${dist}.txt
# done

# # YCSB C
# rm -rf *
# cmake ../learned-leveldb -DCMAKE_BUILD_TYPE=RELEASE -DNDEBUG_SWITCH=ON
# make -j

# OSM
# echo "osm C"
# LINENUM=50000000
# for dist in ycsb_c; do
#     sync; echo 3 | sudo tee /proc/sys/vm/drop_caches
#     echo "${dist} Bourbon"
#     ./read_cold -f /home/kvgroup/cya/learned-leveldb-par/osm/osm-num${LINENUM}-lat-nodup.txt \
#         -k 16 -v 64 -d /home/kvgroup/cya/learned-leveldb-par/testdb-osm${LINENUM}-random -m 7 -u --change_level_load \
#         --YCSB /home/kvgroup/cya/ycsb/${dist}_ordered_run_${LINENUM}_trace.txt \
#         --insert 30008120 -n 10000 -i 5 > ../evaluation-cya/osm_llsm_${dist}.txt
#     echo "${dist} Bourbon"
#     ./read_cold -f /home/kvgroup/cya/learned-leveldb-par/osm/osm-num${LINENUM}-lat-nodup.txt \
#         -k 16 -v 64 -d /home/kvgroup/cya/learned-leveldb-par/testdb-osm${LINENUM}-random -m 7 -u --change_level_load \
#         --YCSB /home/kvgroup/cya/ycsb/${dist}_ordered_run_${LINENUM}_trace.txt \
#         --insert 30008120 -n 10000 -i 5 > ../evaluation-cya/osm_llsm_${dist}.txt
#     echo "${dist} WiscKey"
#     ./read_cold -f /home/kvgroup/cya/learned-leveldb-par/osm/osm-num${LINENUM}-lat-nodup.txt \
#         -k 16 -v 64 -d /home/kvgroup/cya/learned-leveldb-par/testdb-osm${LINENUM}-random -m 8 -u \
#         --YCSB /home/kvgroup/cya/ycsb/${dist}_ordered_run_${LINENUM}_trace.txt \
#         --insert 30008120 -n 10000 -i 5 > ../evaluation-cya/osm_baseline_${dist}.txt
# done

# # YCSB hashed
# echo "YCSB hashed C"
# LINENUM=30000000
# for dist in ycsb_c; do
#     sync; echo 3 | sudo tee /proc/sys/vm/drop_caches
#     echo "${dist} Bourbon"
#     ./read_cold -f /home/kvgroup/cya/ycsb/ycsb_hashed_load_30000000-prcd.txt \
#         -k 16 -v 64 -d /home/kvgroup/cya/learned-leveldb-par/testdb-ycsb-hashed -m 7 -u --change_level_load \
#         --YCSB /home/kvgroup/cya/ycsb/${dist}_ordered_run_${LINENUM}_trace.txt \
#         --insert 30000000 -n 10000 -i 5 > ../evaluation-cya/ycsb_llsm_${dist}.txt
#     echo "${dist} Bourbon"
#     ./read_cold -f /home/kvgroup/cya/ycsb/ycsb_hashed_load_30000000-prcd.txt \
#         -k 16 -v 64 -d /home/kvgroup/cya/learned-leveldb-par/testdb-ycsb-hashed -m 7 -u --change_level_load \
#         --YCSB /home/kvgroup/cya/ycsb/${dist}_ordered_run_${LINENUM}_trace.txt \
#         --insert 30000000 -n 10000 -i 5 > ../evaluation-cya/ycsb_llsm_${dist}.txt
#     echo "${dist} WiscKey"
#     ./read_cold -f /home/kvgroup/cya/ycsb/ycsb_hashed_load_30000000-prcd.txt \
#         -k 16 -v 64 -d /home/kvgroup/cya/learned-leveldb-par/testdb-ycsb-hashed -m 8 -u \
#         --YCSB /home/kvgroup/cya/ycsb/${dist}_ordered_run_${LINENUM}_trace.txt \
#         --insert 30000000 -n 10000 -i 5 > ../evaluation-cya/ycsb_baseline_${dist}.txt
# done
