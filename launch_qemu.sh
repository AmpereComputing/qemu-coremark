#!/usr/bin/env bash

# Copyright (c) 2024, Ampere Computing LLC
#
# SPDX-License-Identifier: BSD-3-Clause

set -o errexit
set -o nounset

bash stop_qemu.sh
sleep 5

# Download img file (debian genericcloud arm64) to load into QEMU
if [ ! -f "disk.qcow2" ]; then
  echo "Downloading Debian 'genericcloud' arm64 image"
  wget -c -O debian-12-genericcloud-arm64-20240901-1857.qcow2 https://cloud.debian.org/images/cloud/bookworm/20240901-1857/debian-12-genericcloud-arm64-20240901-1857.qcow2
  ./qemu-9.1.0/build/qemu-img resize -q debian-12-genericcloud-arm64-20240901-1857.qcow2 5G
fi

if [ "$(uname -m)" = "aarch64" ]; then
  QEMU_CPU="host"
  QEMU_EXTRA_FLAGS="-enable-kvm"
else
  QEMU_CPU="neoverse-n1"
  QEMU_EXTRA_FLAGS=""
fi

echo -n "Running QEMU VMs"

bash ./thread.sh

count=0
portnum=2000
qemu_pids=()
while read line; do
  if [ ! -f "disk${count}.qemu" ]; then
    ./qemu-9.1.0/build/qemu-img create -q -f qcow2 -F qcow2 -b debian-12-genericcloud-arm64-20240901-1857.qcow2 disk${count}.qcow2
  fi

  nohup taskset -c ${line} \
    $PWD/qemu-9.1.0/build/qemu-system-aarch64 \
      -machine virt,gic-version=max        \
      -m 4G                                \
      -cpu ${QEMU_CPU}                     \
      -smp 4                               \
      -device virtio-net-pci,netdev=eth0   \
      -netdev user,id=eth0,hostfwd=tcp::${portnum}-:22           \
      -drive file=disk${count}.qcow2,format=qcow2,if=none,id=drive0,cache=writeback -device virtio-blk,drive=drive0,bootindex=0 \
      -drive file=user-data.img,format=raw,readonly=on,if=virtio \
      -drive file=fat:rw:phoronix-test-suite                     \
      -chardev file,id=char0,path=/tmp/qemu-serial-${count}.log,signal=off -serial chardev:char0 \
      -drive if=pflash,format=raw,file=efi-code.img,readonly=on  \
      -drive if=pflash,format=raw,file=efi-vars.img              \
      ${QEMU_EXTRA_FLAGS} -display none > /tmp/qemu${count}.log 2>&1 &

  echo -n "."
  qemu_pids+=($!)

  count=$((count+1))
  portnum=$((portnum+1))
done < core_spread.txt
echo ""

# Give the last QEMU VM some time to start running
sleep 5

echo "Checking if VMs successfully started."
count=0
for p in "${qemu_pids[@]}"; do
  if ! kill -0 $p 2>/dev/null; then
    #wait $!
    echo "QEMU VM ${count} failed to start. See /tmp/qemu${count}.log for details."
    exit 1
  fi
  count=$((count+1))
done

echo "Waiting for VMs to finish booting and installing pts/coremark."
count=0
while read line; do
  if ! grep -q 'Cloud-init target.' "/tmp/qemu-serial-${count}.log"; then
    echo "Waiting for VM ${count} (check /tmp/qemu-serial-${count}.log for progress)"
    while ! grep -q 'Cloud-init target.' "/tmp/qemu-serial-${count}.log"; do
      sleep 2
      echo -n "."
    done
    echo ""
  fi
  count=$((count+1))
done < core_spread.txt


echo "The QEMU VMs are ready."
