#!/bin/bash

set -e

IMAGE_NAME=${IMAGE_NAME:-ubuntu-24}
UBUNTU_FS_WORKDIR=${UBUNTU_FS_WORKDIR:-ubuntu_fs}
OS_USER=${OS_USER:-linaro}
OS_PASSWD=${OS_PASSWD:-linaro}

OS_REPO=${OS_REPO:-http://nova.clouds.ports.ubuntu.com}
OS_IMAGE_SIZE=${OS_IMAGE_SIZE:-4}

OS_VERSION=${OS_VERSION:-24.04.2}
ARCHIVE_FILE=${ARCHIVE_FILE:-ubuntu-base-${OS_VERSION//\"/}-base-arm64.tar.gz}
ARCHIVE_URL=${ARCHIVE_URL:-"https://cdimage.ubuntu.com/ubuntu-base/releases/${OS_VERSION//\"/}/release/${ARCHIVE_FILE//\"/}"}

OS_NAME=${OS_NAME:-noble}
prefix=${OS_VERSION:0:2}
if [ "$prefix" = "24" ]; then
  OS_NAME=noble
else
  echo "Currently only support Ubuntu 24.04 and Ubuntu 22.04"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo "Need to run with sudo"
   exit 1
fi

# Check if the img file name parameter is provided
if [ -z "$IMAGE_NAME" ]; then
    echo "Please provide the generated img file name as the first parameter!"
    exit 1
fi

#Generate an img file
echo "Generating $OS_IMAGE_SIZE GB img file $IMAGE_NAME ..."
dd if=/dev/zero of=$IMAGE_NAME bs=1G count=$OS_IMAGE_SIZE || exit 1

# Format the img file as ext4 file system
echo "Formatting the img file as ext4 file system..."
mkfs.ext4 -F $IMAGE_NAME || exit 1

# Check if the directory exists
if [ -d $UBUNTU_FS_WORKDIR ]; then
    echo "Directory $UBUNTU_FS_WORKDIR exists. Deleting its contents..."
    rm -rf $UBUNTU_FS_WORKDIR/*
else
    echo "Directory $UBUNTU_FS_WORKDIR does not exist. Creating the directory..."
    mkdir $UBUNTU_FS_WORKDIR
fi

# Mount the img file to the ubuntu_fs directory
echo "Mounting the img file to directory $UBUNTU_FS_WORKDIR..."
mount -o loop $IMAGE_NAME $UBUNTU_FS_WORKDIR || exit 1

# Download the file
echo "Downloading file $ARCHIVE_FILE ..."
wget $ARCHIVE_URL -P $UBUNTU_FS_WORKDIR

# Extract the file
echo "Extracting file $ARCHIVE_FILE to directory $UBUNTU_FS_WORKDIR..."
tar -xf $UBUNTU_FS_WORKDIR/$ARCHIVE_FILE -C $UBUNTU_FS_WORKDIR

# Remove the downloaded archive file
echo "Removing downloaded archive file $ARCHIVE_FILE ..."
rm $UBUNTU_FS_WORKDIR/$ARCHIVE_FILE

# Write nameserver to resolv.conf file
echo "Writing nameserver to $UBUNTU_FS_WORKDIR/etc/resolv.conf file..."
echo "nameserver 8.8.8.8" > "$UBUNTU_FS_WORKDIR/etc/resolv.conf"

cat > "$UBUNTU_FS_WORKDIR/etc/apt/sources.list" << EOF
deb $OS_REPO/ubuntu-ports/ $OS_NAME main restricted
deb $OS_REPO/ubuntu-ports/ $OS_NAME-updates main restricted
deb $OS_REPO/ubuntu-ports/ $OS_NAME universe
deb $OS_REPO/ubuntu-ports/ $OS_NAME-updates universe
deb $OS_REPO/ubuntu-ports/ $OS_NAME multiverse
deb $OS_REPO/ubuntu-ports/ $OS_NAME-updates multiverse
deb $OS_REPO/ubuntu-ports/ $OS_NAME-backports main restricted universe multiverse
deb $OS_REPO/ubuntu-ports/ $OS_NAME-security main restricted
deb $OS_REPO/ubuntu-ports/ $OS_NAME-security universe
deb $OS_REPO/ubuntu-ports/ $OS_NAME-security multiverse
EOF

# Switch to chroot environment and execute apt command
echo "Switching to chroot environment and executing apt command..."
mount -t proc /proc "$UBUNTU_FS_WORKDIR"/proc
mount -t sysfs /sys "$UBUNTU_FS_WORKDIR"/sys
mount -o bind /dev "$UBUNTU_FS_WORKDIR"/dev
mount -o bind /dev/pts "$UBUNTU_FS_WORKDIR"/dev/pts
chroot "$UBUNTU_FS_WORKDIR" /bin/bash -c "DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt update -y" || exit 1

# Create a new user with sudo privileges
echo "Creating user $OS_USER with sudo privileges..."
chroot "$UBUNTU_FS_WORKDIR" /bin/bash -c "useradd -m -s /bin/bash -G sudo $OS_USER" || exit 1

# Set the password for the new user
echo "Setting password for user $OS_USER..."
echo "$OS_USER:$OS_PASSWD" | chroot "$UBUNTU_FS_WORKDIR" /bin/bash -c "chpasswd" || exit 1

chroot $UBUNTU_FS_WORKDIR /bin/bash -c "chmod 1777 /tmp" || exit 1

echo "Generate the init file"
cat > $UBUNTU_FS_WORKDIR/init << EOF
#!/bin/sh

[ -d /dev ] || mkdir -m 0755 /dev
[ -d /root ] || mkdir -m 0700 /root
[ -d /sys ] || mkdir /sys
[ -d /proc ] || mkdir /proc
[ -d /tmp ] || mkdir /tmp
mkdir -p /var/lock
mount -t sysfs -o nodev,noexec,nosuid sysfs /sys
mount -t proc -o nodev,noexec,nosuid proc /proc
# Some things don't work properly without /etc/mtab.
ln -sf /proc/mounts /etc/mtab

grep -q '\<quiet\>' /proc/cmdline || echo "Loading, please wait..."

# Note that this only becomes /dev on the real filesystem if udev's scripts
# are used; which they will be, but it's worth pointing out
if ! mount -t devtmpfs -o mode=0755 udev /dev; then
        echo "W: devtmpfs not available, falling back to tmpfs for /dev"
        mount -t tmpfs -o mode=0755 udev /dev
        [ -e /dev/console ] || mknod -m 0600 /dev/console c 5 1
        [ -e /dev/null ] || mknod /dev/null c 1 3
fi
mkdir /dev/pts
mount -t devpts -o noexec,nosuid,gid=5,mode=0620 devpts /dev/pts || true
mount -t tmpfs -o "noexec,nosuid,size=10%,mode=0755" tmpfs /run
mkdir /run/initramfs
# compatibility symlink for the pre-oneiric locations
ln -s /run/initramfs /dev/.initramfs

# Set modprobe env
export MODPROBE_OPTIONS="-qb"

# mdadm needs hostname to be set. This has to be done before the udev rules are called!
if [ -f "/etc/hostname" ]; then
        /bin/hostname -b -F /etc/hostname 2>&1 1>/dev/null
fi

exec /sbin/init
EOF
chmod +x $UBUNTU_FS_WORKDIR/init || exit 1

chroot $UBUNTU_FS_WORKDIR /bin/bash -c "apt install systemd iptables -y" || exit 1
chroot $UBUNTU_FS_WORKDIR /bin/bash -c "ln -s /lib/systemd/systemd /sbin/init" || exit 1

echo "Install other essential components, in case of booting blocking at /dev/hvc0 failed to bring up"
chroot $UBUNTU_FS_WORKDIR /bin/bash -c "apt install vim bash-completion net-tools iputils-ping ifupdown ethtool ssh rsync udev htop rsyslog curl openssh-server apt-utils dialog nfs-common psmisc language-pack-en-base sudo kmod apt-transport-https -y" || exit 1
chroot $UBUNTU_FS_WORKDIR /bin/bash -c "echo 'kata-ubuntu-host' | sudo tee /etc/hostname" || exit 1

chroot $UBUNTU_FS_WORKDIR /bin/bash -c "cat >> /etc/network/interfaces.d/eth0.conf <<EOF
auto enp0s1
iface enp0s1 inet static
    address 192.168.122.22
    netmask 255.255.255.0
    gateway 192.168.122.1
    dns-nameservers 8.8.8.8
EOF"

# Unmount the mounted directory
echo "Unmounting the mounted directory $UBUNTU_FS_WORKDIR ..."
umount $UBUNTU_FS_WORKDIR/proc
umount $UBUNTU_FS_WORKDIR/sys
umount $UBUNTU_FS_WORKDIR/dev/pts
umount $UBUNTU_FS_WORKDIR/dev
umount $UBUNTU_FS_WORKDIR

echo "Build the ubuntu filesystem Operation completed!"
