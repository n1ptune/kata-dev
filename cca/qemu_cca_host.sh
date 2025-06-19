#!/bin/bash

set -euo pipefail

QEMU_BUILD_DIR=${QEMU_BUILD_DIR:-qemu_cca_host}

git clone -b cca/2025-05-28 https://git.codelinaro.org/linaro/dcap/qemu $QEMU_BUILD_DIR
cd $QEMU_BUILD_DIR
./configure --target-list=aarch64-softmmu --enable-slirp
make -j$(nproc)
