#!/usr/bin/env bash

# Copyright (c) 2024, Ampere Computing LLC
#
# SPDX-License-Identifier: BSD-3-Clause

set -o errexit
set -o nounset

# Assign default value if no argument is passed
num_iterations=${1:-1}

num_inst=$(wc -l core_spread.txt | cut -d" " -f1)

ssh_key_file="id_rsa_coremark_qemu"

echo "${num_inst} instances of pts/coremark running in parallel in arm64 VMs!"
ssh_pids=()
# shellcheck disable=SC2034
for iter in $(seq 1 ${num_iterations}); do

  rm -f /tmp/20*
  portnum=2000;

  # shellcheck disable=SC2034
  for i in $(seq 0 $((num_inst-1))); do
    ssh                           \
      -p ${portnum}               \
      -i "${ssh_key_file}"        \
      debian@localhost            \
      -o StrictHostKeyChecking=no \
      "phoronix-test-suite debug-benchmark pts/coremark" >> /tmp/${portnum} 2>&1 &
    ssh_pids+=($!)
    portnum=$((portnum+1))
  done

  for pid in "${ssh_pids[@]}"; do
    wait "${pid}"
  done

  sum=0
  portnum=2000;

  # Add the coremark scores
  # shellcheck disable=SC2034
  for i in $(seq 0 $((num_inst-1))); do
    score=$(cat /tmp/${portnum} | grep "Average: " | cut -d " " -f2 | cut -d"." -f1)
    sum=$((sum+score))
    portnum=$((portnum+1))
  done

  echo "Round ${iter} - Total CoreMark Score is: ${sum}"
done
