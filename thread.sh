#!/usr/bin/env bash

# Copyright (c) 2024, Ampere Computing LLC
#
# SPDX-License-Identifier: BSD-3-Clause

set -o errexit
set -o nounset

cpus=$(lscpu | grep "NUMA node${numa} CPU:" | cut -d: -f2 | sed -e "s/ //g" | sed -e "s/-/ /g")
TPC=$(lscpu | grep "Thread(s) per core:" | cut -d: -f2 | sed -e "s/ //g" | sed -e "s/-/ /g")
CPS=$(lscpu | grep "Core(s) per socket:" | cut -d: -f2 | sed -e "s/ //g" | sed -e "s/-/ /g")
SOC=$(lscpu | grep "Socket(s):" | cut -d: -f2 | sed -e "s/ //g" | sed -e "s/-/ /g")
start_cpu=$(echo $cpus | cut -d" " -f1)
worker_process=$((TPC*CPS*SOC))
org_string=""
new_string=""
i=1
count=1
while [ ${count} -lt $((worker_process-1)) ]; do
        new_string=$(cat /sys/devices/system/cpu/cpu${i}/topology/thread_siblings_list)
        org_string=$(echo ${org_string},${new_string})
        count=$((count+TPC))
        i=$(($i+1))
done
affinity=$(echo ${org_string} | sed -e "s/^,//g")

echo $affinity | sed 's/,/\n/g' | awk 'NR%4==1{x=$0}NR%4==2{x=x","$0}NR%4==3{x=x","$0}NR%4==0{print x","$0}' > core_spread.txt
