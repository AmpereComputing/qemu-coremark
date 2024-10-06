#!/usr/bin/env bash

# Copyright (c) 2024, Ampere Computing LLC
#
# SPDX-License-Identifier: BSD-3-Clause

if [ -f "qemu_pids.txt" ]; then
  QEMU_PIDS="$(cat qemu_pids.txt)"
  # shellcheck disable=SC2059
  kill ${QEMU_PIDS}
fi
rm -f disk*.qcow2
rm -f efi-vars-*.img
rm -f /tmp/qemu*.log
rm -f /tmp/20*
rm -f qemu_pids.txt
rm -f core_spread.txt
