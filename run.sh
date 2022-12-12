#!/bin/bash

# Fix common errors:
# Referencing undefined variables (which default to "")
# Ignoring failing commands
set -o nounset
set -o errexit
set -o pipefail
# set -o xtrace

#
# Configuration section
#
MNT_ROOT=$(mktemp -d)
MNT_FIRM=$(mktemp -d)
DEV_FILE=/dev/sdb
DEV_FILE_FIRM="${DEV_FILE}1"
DEV_FILE_ROOT="${DEV_FILE}2"
DEV_FILE_SWAP="${DEV_FILE}3"
MMSUITE=bullseye
MMARCH=arm64
# As defined at https://www.debian.org/doc/debian-policy/ch-archive.html#s-priorities
# apt, required, important, or standard
MMVARIANT=required
NETPKG=ifupdown,iproute2
export NET_HOSTNAME=testpi
export NET_STATIC_IP=192.168.0.100
export NET_STATIC_GW=192.168.0.1
export NET_STATIC_DNS=192.168.0.5
RASPIFIRMWARE=raspi-firmware,firmware-brcm80211
KERNELPKG=linux-image-arm64
EXTRAPKG="busybox-static,debian-archive-keyring,udev,kmod,e2fsprogs,apt-utils,whiptail,firmware-linux-free,firmware-misc-nonfree"

trap cleanup SIGHUP SIGINT SIGQUIT SIGABRT

cleanup()
{
  #
  # Cleanup section
  #
  echo "* Performing cleanup"
  rm -f "${MNT_ROOT}/provision.sh"
  rm -f "${MNT_ROOT}/.env"
  umount "${MNT_ROOT}/boot/firmware/"
  umount "${MNT_ROOT}"
  rm -rf "${MNT_ROOT}" "${MNT_FIRM}"
}

export DEBIAN_FRONTEND=noninteractive
#
# Setup section
#
# Ensure needed tools are installed
apt update
apt install --no-install-recommends -q -y mmdebstrap qemu-user-static binfmt-support parted dosfstools systemd-container arch-test

#
# Create partitions and filesystem section
#
if [[ ! -b "${DEV_FILE}" ]]; then
  echo "Device not found '${DEV_FILE}'"
  exit 1
fi

# Ensure partitions are unmounted
for i in "${DEV_FILE}"[0-9]; do
  umount -qf "$i" >/dev/null 2>&1 || true
done

# Wipe partition table
dd of=${DEV_FILE} if=/dev/zero bs=1MiB count=256
sync

# Create gpt partition table
parted "${DEV_FILE}" mklabel gpt
#                                         name      fs         start end
parted "${DEV_FILE}" --align=opt -- mkpart RASPIFIRM fat32      0%    256M
parted "${DEV_FILE}" --align=opt -- mkpart RASPIROOT ext4       256M  -2GB
parted "${DEV_FILE}" --align=opt -- mkpart RASPISWAP linux-swap -2GB  100%

while [ ! -b ${DEV_FILE_FIRM} ] && [ ! -b ${DEV_FILE_ROOT} ] && [ ! -b ${DEV_FILE_SWAP} ]; do
  partprobe $DEV_FILE
  sleep 1
done

# Wipe filesystem info
dd of="${DEV_FILE_ROOT}" if=/dev/zero count=512

mkfs.vfat -v -F 32 -n RASPIFIRM "${DEV_FILE_FIRM}"
mkfs.ext4 -L RASPIROOT "${DEV_FILE_ROOT}"
mkswap -f -L RASPISWAP "${DEV_FILE_SWAP}"

#
# Bootstrap Debian section
#
mount "${DEV_FILE_ROOT}" "${MNT_ROOT}"

mmdebstrap --architectures=$MMARCH \
  --variant=$MMVARIANT \
  --components="main contrib non-free" \
  --include=${KERNELPKG},${EXTRAPKG},${NETPKG},${RASPIFIRMWARE} \
  "$MMSUITE" \
  "${MNT_ROOT}"

# mmdebstrap requires its target to be empty, so move firmware files now
mount "${DEV_FILE_FIRM}" "${MNT_FIRM}"
cp -Rp "${MNT_ROOT}/boot/firmware"/* "${MNT_FIRM}"
rm -rf "${MNT_ROOT}/boot/firmware"/*
umount "${MNT_FIRM}"
mount "${DEV_FILE_FIRM}" "${MNT_ROOT}/boot/firmware"

#
# Provision Debian section
#

# Copy provisioning script to target
cp ./provision.sh "${MNT_ROOT}/"

# Dump settings inside target
env > "${MNT_ROOT}/.env"

systemd-nspawn -q -D "${MNT_ROOT}" -a /provision.sh

sed -i "s|${DEV_FILE_ROOT}|LABEL=RASPIROOT|" "${MNT_ROOT}/boot/firmware/cmdline.txt"

cleanup
