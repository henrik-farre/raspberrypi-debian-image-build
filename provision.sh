#!/bin/bash

# Fix common errors:
# Referencing undefined variables (which default to "")
# Ignoring failing commands
set -o nounset
set -o errexit
set -o pipefail
# set -o xtrace

export DEBIAN_FRONTEND=noninteractive

echo "Running provisioning script"

uname -a

cat > /etc/fstab << EOF
LABEL=RASPIROOT		/		ext4	rw		0 1
LABEL=RASPIFIRM		/boot/firmware	vfat	rw		0 2
LABEL=RASPISWAP		none		swap	defaults	0 0
EOF

echo "rootfstype=ext4" > /etc/default/raspi-extra-cmdline
echo "gpu_mem=16" >> /etc/default/raspi-firmware-custom
sed -i 's|#ROOTPART=.*|ROOTPART="LABEL=RASPIROOT"|' /etc/default/raspi-firmware
sed -i 's|#KERNEL_ARCH=.*|KERNEL_ARCH="arm64"|' /etc/default/raspi-firmware

cat > /etc/apt/sources.list << EOF
deb http://deb.debian.org/debian bullseye main contrib non-free
deb http://security.debian.org/ bullseye-security main contrib non-free
deb http://deb.debian.org/debian bullseye-updates main contrib non-free
deb http://deb.debian.org/debian bullseye-backports main contrib non-free
EOF

echo "* Apt update and install extra packages"
apt update -q -y
apt install --no-install-recommends -q -y bash openssh-server curl systemd-timesyncd locales tzdata keyboard-configuration console-setup fake-hwclock python3

echo "* Configuring tzdata"
echo "tzdata tzdata/Areas select Europe" | debconf-set-selections
echo "tzdata tzdata/Zones/Europe select Copenhagen" | debconf-set-selections
rm -f /etc/localtime /etc/timezone
dpkg-reconfigure --frontend noninteractive locales

echo "* Configuring keyboard"
cat > /etc/default/keyboard << EOF
# KEYBOARD CONFIGURATION FILE

# Consult the keyboard(5) manual page.

XKBMODEL="pc105"
XKBLAYOUT="dk"
XKBVARIANT=""
XKBOPTIONS=""

BACKSPACE="guess"
EOF

echo "* Configuring locales"
echo "locales locales/default_environment_locale select da_DK.UTF-8" | debconf-set-selections
echo "locales locales/locales_to_be_generated multiselect da_DK.UTF-8 UTF-8" | debconf-set-selections
rm /etc/locale.gen
dpkg-reconfigure --frontend noninteractive tzdata

# Works but returns errors about:
# W: Couldn't identify type of root file system for fsck hook
# grep: /sys/firmware/devicetree/base/model: No such file or directory
# grep: /proc/device-tree/model: No such file or directory
echo "* Generating initramfs - ignore errors about fsck hook, and missing entries in /sys and /proc"
update-initramfs -u -k all || true

echo "* Disable wpa_supplicant"
rm -f /etc/systemd/system/multi-user.target.wants/wpa_supplicant.service
rm -f /etc/systemd/system/dbus-fi.w1.wpa_supplicant1.service

echo "********************************************************************************"
echo "*"
echo "*"
echo "* Setting root password - REMEMBER TO CHANGE IT"
echo "root:hest1234" | chpasswd

echo "* Enable root login using SSH - REMEMBER TO CHANGE IT"
sed -i 's|#PermitRootLogin.*|PermitRootLogin yes|' /etc/ssh/sshd_config
sed -i 's|UsePAM.*|UsePAM no|' /etc/ssh/sshd_config
echo "*"
echo "*"
echo "********************************************************************************"


fake-hwclock save

echo "Provisioning done"
