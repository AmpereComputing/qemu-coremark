# Phoronix Test Suite CoreMark on arm64 QEMU

## Summary

Use this script to compare the performance of arm64 emulation on x86
versus arm64 virtualization on arm64 hosts, for example Ampere Altra
and [AmpereOne](https://www.linkedin.com/posts/joespeed_ampereone-192-core-arm64-processor-tops-the-activity-7238610861852925953-pJhb).
CoreMark arm64 in QEMU on x86 and arm64 hosts is a good
indication of the relative performance you might expect on your hardware
when doing arm64 software development and testing using QEMU or other
open source and commercial arm SoC emulation and virtualization solutions
including "[Arm Virtual Hardware](https://developer.arm.com/Tools%20and%20Software/Arm%20Virtual%20Hardware)".
This script runs PTS CoreMark arm64 test in as many 4 core QEMU arm64
instances as your x86 and arm64 host will support. CoreMark is a widely
used measure of SoC performance especially automotive ECUs.

## Table of Contents
* [System Requirements](#system-requirements)
* [Setup](#setup)
  * [Build QEMU](#build-qemu)
  * [Launch QEMU](#launch-qemu)
* [Run](#run)
* [Teardown](#teardown)
* [Dependencies](#dependencies)
* [Example Results](#example-results)

## System Requirements
x86 or arm64 Ubuntu 22.04 or 24.04.

It should run on other distros and architectures (POWER, RISCV64, LOONGSON etc.) but we've not tested those.

## Setup
### Build QEMU
```
./build_qemu.sh
```
### Launch QEMU
```
./launch_qemu.sh
```
## Run

Run PTS / coremark on each instance.
Argument 1 is the number of times you want to run CoreMark on each QEMU.
Default Value is 1

```
./run_pts.sh <count>
```
Example - it will report the output as follow -
```
    $ ./run_pts.sh 2
    23 instances of pts/coremark running in parallel in arm64 VMs!
    Round 1 - Total CoreMark Score is: 1937195
    Round 2 - Total CoreMark Score is: 1940554
```
## Teardown
To stop / kill QEMU instances
```
./stop_qemu.sh
```

## Dependencies

Due to the level of automation you will not see prompts for software
installed as part of a benchmark run. Therefore you must accept the
license of each of the benchmarks individually, and take responsibility
for using them before you use the qemu-coremark.

In its current release these are the benchmarks that are executed and
their associated license terms:

`phoronix-test-suite`: [GPLv3](https://github.com/phoronix-test-suite/phoronix-test-suite/blob/master/COPYING)<br />
`coremark`: [Apache v2](https://github.com/eembc/coremark/blob/main/LICENSE.md)

## Example Results

Relative performance of software testing on virtual and emulated arm SoCs using
[qemu-coremark](https://github.com/AmpereComputing/qemu-coremark).

| Number of Parallel Instances | Hardware                                                       | CoreMark Result |
| ---------------------------- | --------                                                       | --------------- |
| 47                           | arm64 Virtual SoCs on System76 Starling Pro AmpereOne 192 core | 4,640,882       |
| 31                           | arm64 Virtual SoCs on System76 developer desktop 128 core      | 2,809,762       |
| 47                           | arm64 Emulated SoCs on AMD Genoa 9654                          | 512,244         |
