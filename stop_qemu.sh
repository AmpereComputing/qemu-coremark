#!/usr/bin/env bash

# Copyright (c) 2024, Ampere Computing LLC
#
# SPDX-License-Identifier: BSD-3-Clause

killall qemu-system-aarch64
rm -rf disk*.qcow2
rm -f /tmp/qemu*.log
