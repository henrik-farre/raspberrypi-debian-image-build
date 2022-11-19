# Raspberry Pi Debian image build

Based on https://github.com/emojifreak/debian-rpi-image-script/blob/a7645b4037ca02c7f1300a7955646ccd05f371c4/debian-rpi-sd-builder.sh

Writes a bootable Debian Bullseye arm64 (aarch64) system to disk (SSD or SD card) that can be used in a Raspberry Pi (Tested on 3B/3B+).

## Requirements

Working Debian install with target disk attached, I use a Vagrant box.

## How to

⚠️ Ensure that "DEV_FILE" in top of `run.sh` points to the target disk - else you will lose data.

As root run: `./run.sh`

## Differences to emojifreak/debian-rpi-image-script

All interative parts have been removed and options hardcoded.

- Disk: gpt partitions, ext4, 2Gb swap
- `parted` for disk partitioning
- Vanilla kernel and not rt version
- Distro: Debian Bullseye arm64
- Uses NetworkManager
- Uses "provision.sh" script inside target to setup system
- Locales default to Europe/Copenhagen, and Danish language and keyboard
- Sets a default root password and enables root login using ssh *REMEMBER TO CHANGE IT*
- Different packages are installed
- Script layout changed and warnings/errors reported by `shellcheck` have been fixed
