#!/bin/bash

set -e

IMG=$1

# Link a loopback device to the img file and get which one was used
LOOP=$(losetup -Pf ${IMG} --show)
function cleanup {
	losetup -d ${LOOP}
}

trap cleanup EXIT

# Allow using second argument to override mount point
MNT=${2:-/tmp/mount${LOOP}}

# Create the mount point and mount the image
mkdir -p ${MNT}
mount ${LOOP}p1 ${MNT}
function cleanup {
	umount ${MNT}
	# rmdir -p ${MNT}
	losetup -d ${LOOP}
}

# Edit files
vim ${MNT}
