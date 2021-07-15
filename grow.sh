#!/bin/bash

set -e

IMG=$1

# Default to 100MB
MEGA=${2:-100}

# Create a dummy partition to help defaults later
fdisk ${IMG} <<EOF > /dev/null
n




w
EOF

# Add zeros to the end of the img file
dd if=/dev/zero bs=1M count=${MEGA} >> ${IMG}

# Grow by deleting existing partition and creating a new one in the same place, but bigger.
fdisk ${IMG} <<EOF > /dev/null
d
2
n
p



d

w
EOF

# Setup loop device for image
LOOP=$(losetup -Pf ${IMG} --show)

trap 'echo Cleaning up...; cleanup' EXIT

function cleanup {
  losetup -d ${LOOP}
}

# Check fs because we can
e2fsck -f ${LOOP}p2

# Grow the ext partition
resize2fs ${LOOP}p2

# Check fs again because we can
e2fsck -f ${LOOP}p2
