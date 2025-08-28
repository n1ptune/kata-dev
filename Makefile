export IMAGE_NAME?=ubuntu_24.img
export UBUNTU_FS_WORKDIR?=ubuntu_fs
export OS_IMAGE_SIZE?=4
export OS_VERSION?=24.04.2

export KERNEL_WORKDIR?=linux_kata_host
export QEMU_WORKDIR?=qemu_cca_host

all: ubuntu_image kata_host_kernel install_kernel_modules qemu_cca_host host_firmware

.PHONY: all clean

ubuntu_image:
	@echo "Starting to build ubuntu image..."
	sudo -E bash ./cca/build_ubuntu_fs.sh

kata_host_kernel:
	@echo "Starting to build host kernel for Kata containers of RME enabled..."
	bash ./cca/kata_host_kernel.sh

install_kernel_modules:
	@echo "Install the kernel modules to ubuntu fs"
	sudo -E bash ./cca/install_modules.sh

qemu_cca_host:
	@echo "Build Qemu CCA Host"
	bash ./cca/build_qemu_host.sh

host_firmware:
	@echo "Build Host Firmware"
	bash ./cca/build_host_firmware.sh

build_kata:
	@echo "Build Kata and CoCo Components and generate Kata release file(runtime Go)"
	bash ./cca/build_kata_cca_components.sh

run_host:
	@echo "Launch the Kata Host"
	bash ./cca/launch_host.sh

kataci-kubeadm-install:
	@echo "Launch the Kata CI Kubeadm"
	sudo -E bash ./kataci/configure-install-kubeadm.sh

kataci-k8s-setup:
	@echo "Launch the Kata CI Kubeadm AIO test node"
	sudo -E bash ./kataci/set-up-k8s.sh

clean:
	@echo "Cleaning up work directory: $(WORK_DIRECTORY)"
	if [ -d "$(UBUNTU_FS_WORKDIR)" ]; then rm -rf "$(UBUNTU_FS_WORKDIR)"; fi
	if [ -d "$(KERNEL_WORKDIR)" ]; then rm -rf "$(KERNEL_WORKDIR)"; fi
	if [ -d "$(QEMU_BUILD_DIR)" ]; then rm -rf "$(QEMU_BUILD_DIR)"; fi
