#!/bin/bash

set -e

# Needed later
QEMU=/usr/bin/qemu-arm-static

ARCH=$(dpkg --print-architecture)

if [[ "${ARCH}" == "armhf" ]]; then
  QEMU=
fi

if [[ "${ARCH}" == "arm64" ]]; then
  QEMU=
fi

if [[ ! -z "${QEMU}" ]]; then
  [ -x ${QEMU} ] || apt-get install qemu qemu-user-static binfmt-support
fi

trap 'echo Cleaning up...; cleanup' EXIT

# Set IMG variable
IMG=$1

# Link a loopback device to the img file and get which one was used
LOOP=$(losetup -Pf ${IMG} --show)
function cleanup {
  losetup -d ${LOOP}
}

MNT=${2:-/tmp/mount${LOOP}}

# Create the mount point and mount the image
mkdir -p ${MNT}
mount ${LOOP}p2 ${MNT}
mount ${LOOP}p1 ${MNT}/boot
function cleanup {
  umount ${MNT}{/boot,}
  # rmdir -p ${MNT}
  losetup -d ${LOOP}
}

# Setup mounts needed for proper chroot
mount -o bind,ro {,${MNT}}/etc/resolv.conf
mount --bind {,${MNT}}/dev
mount --bind {,${MNT}}/dev/pts
mount --bind {,${MNT}}/sys
mount --bind {,${MNT}}/proc
function cleanup {
  umount ${MNT}{/{boot,etc/resolv.conf,dev{/pts,},sys,proc},}
  # rmdir -p ${MNT}
  losetup -d ${LOOP}
}

# Prepare ld.preload for chroot
sed -i 's/^/#CHROOT /g' ${MNT}/etc/ld.so.preload
function cleanup {
  sed -i 's/^#CHROOT //g' ${MNT}/etc/ld.so.preload
  umount ${MNT}{/{boot,etc/resolv.conf,dev{/pts,},sys,proc},}
  # rmdir -p ${MNT}
  losetup -d ${LOOP}
}

echo Chrooting...

# Run the script in Chroot
chroot ${MNT} /bin/bash