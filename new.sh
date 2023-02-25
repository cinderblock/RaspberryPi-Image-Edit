#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

function debug {
	echo -e "${YELLOW}NEW${NC}" "$@"
}

# Make sure we can sudo now. If `curl` finishes in 15min we should be good and it won't ask again
sudo -v

IMG=raspios-lite-$(date --iso-8601=seconds | sed -e 's/-[^-]*$//')-cameron.img

if [[ "$1__" == *.zip__ ]]; then
	ZIP=$1
	debug "Using existing zip as base: ${ZIP}"

	IMG=${2:-$IMG}

	debug "Extracting to: ${IMG}"
	zcat ${ZIP} > ${IMG}
else
	IMG=${1:-$IMG}
	debug "Downloading to: ${IMG}"
	# They always provide exactly one file, the `.img` we care about.
	curl -L https://downloads.raspberrypi.org/raspios_lite_armhf_latest | xzcat > ${IMG}
fi

debug "Growing image"

# Grow by 400MB
sudo ./grow.sh ${IMG} 600

debug "Preparing image"

# Run setup script
sudo LEAVE_HISTORY_ALONE=yes ./chroot.sh ${IMG} setup.sh

# Chroot for fun
#sudo LEAVE_HISTORY_ALONE=yes ./chroot.sh ${IMG}

debug "Compressing image"

#rm "${IMG}"
#xz --force --keep --compress --stdout ${IMG} > temp.img.xz
zip -m ${IMG}{.zip,}
