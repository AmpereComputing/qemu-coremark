#!/usr/bin/env bash

# Copyright (c) 2024, Ampere Computing LLC
#
# SPDX-License-Identifier: BSD-3-Clause

set -o errexit
set -o nounset

# Assign default value if no argument is passed
arg=${1:-1}

num_inst=$(wc -l core_spread.txt | cut -d" " -f1)
num_minus_1=$((num_inst-1))
num_minus_2=$((num_inst-2))
count=0

SSH_KEY_FILE="id_rsa_coremark_qemu"

echo "${num_inst} QEMU running in parallel !"
while true; do

  rm -f /tmp/20*
  portnum=2000;

  for i in $(seq 0 ${num_minus_2}); do
    ssh                           \
      -p ${portnum}               \
      -i "${SSH_KEY_FILE}"        \
      debian@localhost            \
      -o StrictHostKeyChecking=no \
      "phoronix-test-suite debug-benchmark pts/coremark" >> /tmp/${portnum} 2>&1 &
    portnum=$((${portnum}+1))
  done

  ssh                                  \
    -p ${portnum}                      \
    -i ${SSH_KEY_FILE}                 \
    debian@localhost                   \
    -o UserKnownHostsFile=/dev/null    \
    -o StrictHostKeyChecking=no        \
    "phoronix-test-suite debug-benchmark pts/coremark" >> /tmp/${portnum} 2>&1

  sleep 10
  sum=0
  portnum=2000;

  # Add the coremark scores
  for i in $(seq 0 ${num_minus_1}); do
    score=$(cat /tmp/${portnum} | grep "Average: " | cut -d " " -f2 | cut -d"." -f1)
    sum=$((sum+score))
    portnum=$((portnum+1))
  done

  echo "Round ${count} - Total CoreMark Score is: ${sum}"

  count=$((count+1))

  if [ "${count}" -ge "$arg" ]; then
    exit 0;
  fi
done
