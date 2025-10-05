#!/bin/bash

set -e

$QEMU_WORKDIR/build/qemu-system-aarch64 \
-M virt,virtualization=on,secure=on,gic-version=3 \
-M acpi=off -cpu max,x-rme=on,sme=off,pauth-impdef=on \
-m 3G -smp 4 \
-nographic \
-bios ../flash.bin \
-kernel $KERNEL_WORKDIR/arch/arm64/boot/Image \
-drive format=raw,if=none,file=../$IMAGE_NAME,id=hd0 \
-device virtio-blk-pci,drive=hd0 \
-append root=/dev/vda \
-nodefaults \
-serial tcp:localhost:54320 \
-serial tcp:localhost:54321 \
-chardev socket,mux=on,id=hvc0,port=54322,host=localhost \
-device virtio-serial-device \
-device virtconsole,chardev=hvc0 \
-chardev socket,mux=on,id=hvc1,port=54323,host=localhost \
-device virtio-serial-device \
-device virtconsole,chardev=hvc1 \
-append "root=/dev/vda rw earlycon console=hvc0 nokaslr" \
-net nic,macaddr=52:54:30:12:34:63 \
-net tap,ifname=tap1,script=no,downscript=no \
-device virtio-9p-device,fsdev=shr0,mount_tag=shr0 \
-fsdev local,security_model=none,path=.,id=shr0
