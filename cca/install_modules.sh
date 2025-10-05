#!/bin/bash

set -e

if [ ! -d "$UBUNTU_FS_WORKDIR" ]; then
  echo "Please build ubuntu fs first"
  exit 1
fi

if [ ! -d "$KERNEL_WORKDIR" ]; then
  echo "Please build Kata host kernel"
  exit 1
fi

echo "start to mount the image  $IMAGE_NAME at $UBUNTU_FS_WORKDIR"
mount $IMAGE_NAME $UBUNTU_FS_WORKDIR
cd $KERNEL_WORKDIR

make modules_install INSTALL_MOD_PATH=../$UBUNTU_FS_WORKDIR
umount ../$UBUNTU_FS_WORKDIR
