#!/bin/bash

set -e

KERNEL_WORKDIR=${KERNEL_WORKDIR:-linux_kata_host}

git clone -b cca-host/v8 https://git.gitlab.arm.com/linux-arm/linux-cca.git $KERNEL_WORKDIR
cd $KERNEL_WORKDIR
cp arch/arm64/configs/defconfig .config
./scripts/kconfig/merge_config.sh -m .config ../cca/fragment/host-network.conf
./scripts/kconfig/merge_config.sh -m .config ../cca/fragment/cca.conf
./scripts/kconfig/merge_config.sh -m .config ../cca/fragment/kata-cca-host.conf
./scripts/kconfig/merge_config.sh -m .config ../cca/fragment/qemu.conf

yes "" | make -j$(nproc)
