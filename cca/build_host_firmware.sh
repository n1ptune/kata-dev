#!/bin/bash

set -e

TF_RMM_BUILD_DIR=${TF_RMM_BUILD_DIR:-tf-rmm}
TF_A_BUILD_DIR=${TF_A_BUILD_DIR:-trusted-firmware-a}
EDK2_BUILD_DIR=${EDK2_BUILD_DIR:-edk2}

git clone -b cca/v8 https://git.codelinaro.org/linaro/dcap/rmm $TF_RMM_BUILD_DIR
cd $TF_RMM_BUILD_DIR
git submodule update --init --recursive
cmake -DCMAKE_BUILD_TYPE=Debug -DRMM_CONFIG=qemu_virt_defcfg -B build-qemu
cmake --build build-qemu

cd ../
git clone https://github.com/tianocore/edk2.git $EDK2_BUILD_DIR
cd $EDK2_DIR
git submodule update --init --recursive
source edksetup.sh
make -j -C BaseTools
export GCC5_AARCH64_PREFIX=aarch64-linux-gnu-
build -b RELEASE -a AARCH64 -t GCC5 -p ArmVirtPkg/ArmVirtQemuKernel.dsc

cd ../
git clone -b v2.13-rc0 https://git.trustedfirmware.org/TF-A/trusted-firmware-a.git/ $TF_A_BUILD_DIR
cd $TF_A_BUILD_DIR
make -j PLAT=qemu ENABLE_RME=1 DEBUG=1 LOG_LEVEL=40 \
    QEMU_USE_GIC_DRIVER=QEMU_GICV3 RMM=../$TF_RMM_BUILD_DIR/build-qemu/Debug/rmm.img \
    BL33=../$EDK2_BUILD_DIR/Build/ArmVirtQemuKernel-AARCH64/RELEASE_GCC5/FV/QEMU_EFI.fd all fip
dd if=build/qemu/debug/bl1.bin of=flash.bin
dd if=build/qemu/debug/fip.bin of=flash.bin seek=64 bs=4096
mv flash.bin ../
