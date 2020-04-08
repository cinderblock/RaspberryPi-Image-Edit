#!/bin/bash

IMG=$1
MEGA=${2:-100}

# Create a dummy partition to help defaults later
fdisk ${IMG} <<EOF > /dev/null
n




w
EOF

# Grow by 100MB
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
LOOP=$(sudo losetup -Pf ${IMG} --show)
# Check fs because we can
sudo e2fsck -f ${LOOP}p2
# Grow the ext partition
sudo resize2fs ${LOOP}p2
# Check fs again because we can
sudo e2fsck -f ${LOOP}p2
# Cleanup loop device
sudo losetup -d ${LOOP}
