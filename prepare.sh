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
cp {,${MNT}}${QEMU}
# UNDO: rm ${MNT}${QEMU}

# Prepare ld.preload for chroot
sed -i 's/^/#CHROOT /g' ${MNT}/etc/ld.so.preload
# UNDO: sed -i 's/^#CHROOT //g' ${MNT}/etc/ld.so.preload

# Copy setup script to image
cp {,${MNT}/}setup.sh
chmod +x ${MNT}/setup.sh
# UNDO: rm ${MNT}/setup.sh

echo Setting up...

# Run the script in Chroot
chroot ${MNT} /setup.sh

echo Cleaning up...

# cleanup script
rm ${MNT}/setup.sh

# Full reset
rm ${MNT}${QEMU}
sed -i 's/^#CHROOT //g' ${MNT}/etc/ld.so.preload
umount ${MNT}{/{boot,dev{/pts,},sys,proc},}
losetup -d ${LOOP}
