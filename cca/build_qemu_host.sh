#!/bin/bash

set -e

QEMU_WORKDIR=${QEMU_WORKDIR:-qemu_cca_host}

git clone -b cca/2025-05-28 https://git.codelinaro.org/linaro/dcap/qemu $QEMU_WORKDIR
cd $QEMU_WORKDIR
./configure --target-list=aarch64-softmmu --enable-slirp
make -j$(nproc)
