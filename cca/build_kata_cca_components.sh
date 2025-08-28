#!/bin/bash

set -e

KATA_WORKDIR=${KATA_WORKDIR:-kata-containers}
LOCAL_BUILD_WORKDIR=$KATA_WORKDIR/tools/packaging/kata-deploy/local-build
git clone -b add-cca https://github.com/kevinzs2048/kata-containers.git $KATA_WORKDIR
cd $LOCAL_BUILD_WORKDIR
sudo rm build -rf
make kernel-cca-confidential-tarball shim-v2-tarball qemu-cca-experimental-tarball rootfs-cca-confidential-image-tarball rootfs-cca-confidential-initrd-tarball ovmf-cca-tarball
echo "The generated Kata tar files are in build directory"

cd $KATA_WORKDIR
mkdir kata-artifacts
mv ${LOCAL_BUILD_WORKDIR}/build/kata-static-*.tar.xz kata-artifacts
