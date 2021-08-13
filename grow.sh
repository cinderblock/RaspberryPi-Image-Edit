#!/bin/bash

set -e

IMG=$1

# Default to 100MB
MEGA=${2:-100}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

function debug {
	echo -e "${GREEN}GROW${NC}" "$@"
	:
}

debug "Growing image ${IMG} by ${MEGA}MB"

debug "Creating dummy partition"

# Create a dummy partition to help defaults later
# The empty lines are significant
fdisk ${IMG} <<- EOF > /dev/null
	n




	w
EOF

debug "Growing the real file"

# Add zeros to the end of the img file
truncate -s +${MEGA}M ${IMG}

debug "Extending partition"

# Grow by deleting existing partition and creating a new one in the same place, but bigger.
# The empty lines are significant
fdisk ${IMG} <<- EOF > /dev/null 2> /dev/null
	d
	2
	n
	p



	d

	w
EOF

# Setup loop device for image
LOOP=$(losetup -Pf ${IMG} --show)

trap cleanup EXIT

function cleanup {
	debug "Cleaning up..."
	losetup -d ${LOOP}
}

debug "Checking filesystem"

# Check fs because we can
e2fsck -fy ${LOOP}p2 > /dev/null

debug "Growing filesystem"

# Grow the ext partition
resize2fs ${LOOP}p2 > /dev/null

debug "Checking filesystem (again)"

# Check fs again because we can
e2fsck -fy ${LOOP}p2 > /dev/null
