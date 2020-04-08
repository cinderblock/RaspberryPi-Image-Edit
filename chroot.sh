#!/bin/bash

set -e

# Needed later
QEMU=/usr/bin/qemu-arm-static

[ -x ${QEMU} ] || apt-get install qemu qemu-user-static binfmt-support

# Set IMG variable
IMG=$1

# Link a loopback device to the img file and get which one was used
LOOP=$(losetup -Pf ${IMG} --show)
# UNDO: losetup -d ${LOOP}

MNT=${2:-/tmp/mount${LOOP}}

# Create the mount point and mount the image
mkdir -p ${MNT}
mount ${LOOP}p2 ${MNT}
mount ${LOOP}p1 ${MNT}/boot
# UNDO: umount ${MNT}{/boot,}

# Setup mounts needed for proper chroot
mount --bind {,${MNT}}/dev
mount --bind {,${MNT}}/sys
mount --bind {,${MNT}}/proc
mount --bind {,${MNT}}/dev/pts
# UNDO: umount ${MNT}/{dev{/pts,},sys,proc}

# Make QEMU binary available in chroot
touch ${MNT}${QEMU}
mount -o ro,bind {,${MNT}}${QEMU}
# UNDO: umount ${MNT}${QEMU} && rm ${MNT}${QEMU}

# Prepare ld.preload for chroot
sed -i 's/^/#QEMU /g' ${MNT}/etc/ld.so.preload

echo Chrooting...

# Run the script in Chroot
chroot ${MNT} /bin/bash

echo Cleaning up...

# Full reset
sudo umount ${MNT}${QEMU}
sudo rm ${MNT}${QEMU}
sudo sed -i 's/^#QEMU //g' ${MNT}/etc/ld.so.preload
sudo umount ${MNT}{/{boot,dev{/pts,},sys,proc},}
sudo losetup -d ${LOOP}
