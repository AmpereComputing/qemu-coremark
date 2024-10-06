#!/usr/bin/env bash

# Copyright (c) 2024, Ampere Computing LLC
#
# SPDX-License-Identifier: BSD-3-Clause

# Runs coremark in an arm64 QEMU VM
# Version 20241005-01

set -o errexit
set -o nounset

. env.sh

echo "Checking for prerequisites"

DISTRO_LIKE="$(grep ID_LIKE /etc/os-release | awk -F '=' '{print $2}')"

if [ "${DISTRO_LIKE}" = "debian" ]; then
  QEMU_AARCH64_FW="/usr/share/qemu-efi-aarch64/QEMU_EFI.fd"
  if ! command -v ninja; then
    echo "Installing Ninja Build"
    sudo apt-get install -y ninja-build
  fi
  if ! command -v gcc; then
    echo "Installing gcc"
    sudo apt-get install -y gcc
  fi
  if ! command -v g++; then
    echo "Instaling g++"
    sudo apt-get install -y g++
  fi
  if ! command -v make; then
    echo "Installing make"
    sudo apt-get install -y make
  fi
  if ! command -v wget; then
    echo "Installing wget"
    sudo apt-get install -y wget
  fi
  if ! command -v git; then
    echo "Installing git"
    sudo apt-get install -y git
  fi
  if ! command -v cloud-localds; then
    echo "Installing cloud-image-utils"
    sudo apt-get install -y cloud-image-utils
  fi
  if [ ! -e "${QEMU_AARCH64_FW}" ]; then
    echo "Installing QEMU AArch64 UEFI firmware"
    sudo apt-get install -y qemu-efi-aarch64
  fi
  if dpkg -l | grep -q "^ii libglib2.0-dev"; then
    echo "Instaling libglib2.0-dev"
    sudo apt-get install -y libglib2.0-dev
  fi
  if dpkg -l | grep -q "^ii python3-venv"; then
    echo "Instaling python3-venv"
    sudo apt-get install -y python3-venv
  fi
  if ! command -v bzip2; then
    echo "Instaling bzip2"
    sudo apt-get install -y bzip2
  fi
elif [ ! "$(command -v ninja)" ] || [ ! "$(command -v gcc)" ] || [ ! "$(command -v g++)" ] || [ ! "$(command -v git)" ] ||
     [ ! "$(command -v make)" ] || [ ! "$(command -v wget)" ] || [ ! "$(command -v  cloud-localds)" ] ||
     [ ! "$(command -v bzip2)" ]; then
  echo "This script only automatically installs required packages on Debian-like distros."
  echo "The following tools are needed:"
  echo "  ninja gcc g++ make wget git cloud-localds bzip2 libglib2.0-dev python3-venv"
  echo ""
  echo "  cloud-localds is part of Canonical's cloud-utils package,"
  echo "  which can be found at https://github.com/canonical/cloud-utils/"
  echo ""
  echo "  QEMU arm64 firmware is also needed. Set \$QEMU_AARCH64_FW to the filename."
  exit 1
else
  QEMU_AARCH64_FW="${QEMU_AARCH64_FW:-/usr/share/qemu/aavmf-aarch64-code.bin}"
fi

echo "Downloading Phoronix Test Suite"
mkdir phoronix-test-suite || true
pushd phoronix-test-suite || exit 1
wget -c -O "phoronix-test-suite_${PTS_VERSION}_all.deb" "https://phoronix-test-suite.com/releases/repo/pts.debian/files/phoronix-test-suite_${PTS_VERSION}_all.deb"
cat >phoronix-test-suite.xml <<EOF
<?xml version="1.0"?>
<!--Phoronix Test Suite v10.8.4-->
<PhoronixTestSuite>
  <Options>
    <OpenBenchmarking>
      <AnonymousUsageReporting>FALSE</AnonymousUsageReporting>
      <IndexCacheTTL>3</IndexCacheTTL>
      <AlwaysUploadSystemLogs>FALSE</AlwaysUploadSystemLogs>
      <AllowResultUploadsToOpenBenchmarking>FALSE</AllowResultUploadsToOpenBenchmarking>
    </OpenBenchmarking>
    <General>
      <DefaultBrowser></DefaultBrowser>
      <UsePhodeviCache>TRUE</UsePhodeviCache>
      <DefaultDisplayMode>DEFAULT</DefaultDisplayMode>
      <PhoromaticServers></PhoromaticServers>
      <ColoredConsole>AUTO</ColoredConsole>
    </General>
    <Modules>
      <AutoLoadModules>toggle_screensaver, update_checker, perf_tips, ob_auto_compare, load_dynamic_result_viewer</AutoLoadModules>
    </Modules>
    <Installation>
      <RemoveDownloadFiles>FALSE</RemoveDownloadFiles>
      <SearchMediaForCache>TRUE</SearchMediaForCache>
      <SymLinkFilesFromCache>FALSE</SymLinkFilesFromCache>
      <PromptForDownloadMirror>FALSE</PromptForDownloadMirror>
      <EnvironmentDirectory>~/.phoronix-test-suite/installed-tests/</EnvironmentDirectory>
      <CacheDirectory>~/.phoronix-test-suite/download-cache/</CacheDirectory>
    </Installation>
    <Testing>
      <SaveSystemLogs>TRUE</SaveSystemLogs>
      <SaveInstallationLogs>TRUE</SaveInstallationLogs>
      <SaveTestLogs>TRUE</SaveTestLogs>
      <RemoveTestInstallOnCompletion>FALSE</RemoveTestInstallOnCompletion>
      <ResultsDirectory>~/.phoronix-test-suite/test-results/</ResultsDirectory>
      <AlwaysUploadResultsToOpenBenchmarking>FALSE</AlwaysUploadResultsToOpenBenchmarking>
      <AutoSortRunQueue>TRUE</AutoSortRunQueue>
      <ShowPostRunStatistics>TRUE</ShowPostRunStatistics>
    </Testing>
    <TestResultValidation>
      <DynamicRunCount>TRUE</DynamicRunCount>
      <LimitDynamicToTestLength>20</LimitDynamicToTestLength>
      <StandardDeviationThreshold>2.5</StandardDeviationThreshold>
      <ExportResultsTo></ExportResultsTo>
      <MinimalTestTime>2</MinimalTestTime>
      <DropNoisyResults>FALSE</DropNoisyResults>
    </TestResultValidation>
    <ResultViewer>
      <WebPort>RANDOM</WebPort>
      <LimitAccessToLocalHost>TRUE</LimitAccessToLocalHost>
      <AccessKey></AccessKey>
      <AllowSavingResultChanges>TRUE</AllowSavingResultChanges>
      <AllowDeletingResults>TRUE</AllowDeletingResults>
    </ResultViewer>
    <BatchMode>
      <SaveResults>TRUE</SaveResults>
      <OpenBrowser>FALSE</OpenBrowser>
      <UploadResults>FALSE</UploadResults>
      <PromptForTestIdentifier>FALSE</PromptForTestIdentifier>
      <PromptForTestDescription>FALSE</PromptForTestDescription>
      <PromptSaveName>FALSE</PromptSaveName>
      <RunAllTestCombinations>TRUE</RunAllTestCombinations>
      <Configured>TRUE</Configured>
    </BatchMode>
    <Networking>
      <NoInternetCommunication>FALSE</NoInternetCommunication>
      <NoNetworkCommunication>FALSE</NoNetworkCommunication>
      <Timeout>20</Timeout>
      <ProxyAddress></ProxyAddress>
      <ProxyPort></ProxyPort>
      <ProxyUser></ProxyUser>
      <ProxyPassword></ProxyPassword>
    </Networking>
    <Server>
      <RemoteAccessPort>RANDOM</RemoteAccessPort>
      <Password></Password>
      <WebSocketPort>RANDOM</WebSocketPort>
      <AdvertiseServiceZeroConf>FALSE</AdvertiseServiceZeroConf>
      <AdvertiseServiceOpenBenchmarkRelay>FALSE</AdvertiseServiceOpenBenchmarkRelay>
      <PhoromaticStorage>~/.phoronix-test-suite/phoromatic/</PhoromaticStorage>
    </Server>
  </Options>
</PhoronixTestSuite>
EOF
popd || exit 1

# Build QEMU
echo "${QEMU_MD5} qemu-${QEMU_VERSION}.tar.gz" > MD5SUM
if ! md5sum -c MD5SUM; then
  echo "Downloading QEMU"
  wget -c -O qemu-${QEMU_VERSION}.tar.gz https://github.com/qemu/qemu/archive/refs/tags/v${QEMU_VERSION}.tar.gz
fi
tar xf qemu-${QEMU_VERSION}.tar.gz
pushd qemu-${QEMU_VERSION} || exit 1
if [ ! -e "build/qemu-system-aarch64" ]; then
  echo "Building QEMU"
  ./configure --target-list=aarch64-softmmu --enable-slirp --enable-kvm
  make -j "$(nproc)"
fi
popd || exit 1

echo "Setting up VM configuration"

cp -vf "${QEMU_AARCH64_FW}" efi-code.img

truncate -s 64m efi-code.img

SSH_KEY_FILE="id_rsa_coremark_qemu"
if [ ! -e "${SSH_KEY_FILE}" ]; then
  ssh-keygen -t rsa -f "${SSH_KEY_FILE}" -q -P ""
fi
SSH_PUBKEY=$(cat ${SSH_KEY_FILE}.pub)

# create user-data.yaml
cat >user-data.yaml <<EOF
#cloud-config
ssh_pwauth: False
users:
  - default
  - name: debian
    ssh-authorized-keys:
      - ${SSH_PUBKEY}
chpasswd: { expire: False }
mounts:
  - [ /dev/vdc1, /mnt, "auto", "defaults" ]
runcmd:
  - echo "Installing Phoronix Test Suite"
  - cp -f /mnt/phoronix-test-suite.xml /etc/
  - apt-get update
  - apt-get install -y /mnt/phoronix-test-suite_10.8.4_all.deb
  - echo "Installing pts/coremark..."
  - phoronix-test-suite install pts/coremark
EOF

# create user-data.img file
cloud-localds -v user-data.img user-data.yaml
