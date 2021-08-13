#!/bin/bash

# Make sure we bail on the first error
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

function debug {
	echo -e "${GREEN}CHROOT${NC}" "$@"
	:
}

if [[ "$(dpkg --print-architecture)" != "armhf" ]]; then
	debug "Using QEMU"
	QEMU=/usr/bin/qemu-arm-static
	[ -x ${QEMU} ] || apt-get install qemu qemu-user-static binfmt-support
fi

IMG=$1

# Link a loopback device to the img file and get which one was used
LOOP=$(losetup -Pf ${IMG} --show)
	function EXIT_LOSETUP_CLEANUP { debug "Removing loopback device"; losetup -d ${LOOP}; }
	trap EXIT_LOSETUP_CLEANUP EXIT

debug "Loop device: ${LOOP}"

# Allow using second argument to override mount point
MNT=${3:-/tmp/mount${LOOP}}

EXEC=${2}

debug "Mount point: ${MNT}"

PERSIST=.persist

ROOT_HISTORY=${PERSIST}/bash_history.root
PI_HISTORY=${PERSIST}/bash_history.pi

# Ensure history files exist locally
mkdir -p ${PERSIST}
touch ${ROOT_HISTORY} ${PI_HISTORY}

# Ensure our mount point exists
	trap EXIT_RM_MNT_CLEANUP EXIT
	function EXIT_RM_MNT_CLEANUP { EXIT_LOSETUP_CLEANUP; }
if [[ ! -d ${MNT} ]]; then
	debug "Creating the mount point"
	mkdir -p ${MNT}
		function EXIT_RM_MNT_CLEANUP { debug "Removing mount point we created"; rmdir -p --ignore-fail-on-non-empty "${MNT}"; EXIT_LOSETUP_CLEANUP; }
fi

# Mount root
mount -o noatime,data=writeback,nobh,barrier=0,commit=300 ${LOOP}p2 ${MNT}
	function EXIT_UMOUNT_CLEANUP { debug "Unmounting all mountpoints"; umount -R ${MNT}; EXIT_RM_MNT_CLEANUP; }
	trap EXIT_UMOUNT_CLEANUP EXIT

# Ensure history files exist on image
	function EXIT_BASH_HISTORY_ROOT_CLEANUP { EXIT_UMOUNT_CLEANUP; }
	trap EXIT_BASH_HISTORY_ROOT_CLEANUP EXIT
if [[ -z "${LEAVE_HISTORY_ALONE}" && ! -e "${MNT}/root/.bash_history" ]]; then
	debug "Creating ${MNT}/root/.bash_history"
	touch "${MNT}/root/.bash_history"
	mount -o bind,rw ${ROOT_HISTORY} ${MNT}/root/.bash_history
		function EXIT_BASH_HISTORY_ROOT_CLEANUP { debug "Unmounting root .bash_history"; umount "${MNT}/root/.bash_history"; rm "${MNT}/root/.bash_history"; EXIT_UMOUNT_CLEANUP; };
fi
	function EXIT_BASH_HISTORY_PI_CLEANUP { EXIT_BASH_HISTORY_ROOT_CLEANUP; }
	trap EXIT_BASH_HISTORY_PI_CLEANUP EXIT
if [[ -z "${LEAVE_HISTORY_ALONE}" && ! -e "${MNT}/home/pi/.bash_history" ]]; then
	debug "Creating ${MNT}/home/pi/.bash_history"
	touch "${MNT}/home/pi/.bash_history"
	chown 1000:1000 "${PI_HISTORY}"
	mount -o bind,rw,mirror=pi "${PI_HISTORY}" "${MNT}/home/pi/.bash_history"
		function EXIT_BASH_HISTORY_PI_CLEANUP { debug "Unmounting pi .bash_history"; umount "${MNT}/home/pi/.bash_history"; rm "${MNT}/home/pi/.bash_history"; EXIT_BASH_HISTORY_ROOT_CLEANUP; };
fi

# Create file to bind qemu to
	function EXIT_QEMU_CLEANUP { EXIT_BASH_HISTORY_PI_CLEANUP; }
	trap EXIT_QEMU_CLEANUP EXIT
if [[ ! -z "${QEMU}" && ! -e "${MNT}${QEMU}" ]]; then
	debug "Creating ${MNT}${QEMU}"
	touch "${MNT}${QEMU}"
	mount -o bind,ro {,${MNT}}${QEMU}
		function EXIT_QEMU_CLEANUP { debug "Unmounting QEMU"; umount "${MNT}${QEMU}" || :; rm "${MNT}${QEMU}"; EXIT_BASH_HISTORY_PI_CLEANUP; };
fi

TMP=/tmp

debug "Mounting rest of filesystem"
mount -o noatime "${LOOP}p1" "${MNT}/boot"
# Needed by chroot
mount -o bind,ro /dev/null "${MNT}/etc/ld.so.preload"
# Current DNS
mount -o bind,ro "$(realpath /etc/resolv.conf)" "${MNT}/etc/resolv.conf"

mount -o bind,ro {,${MNT}}/dev
mount -o bind,ro {,${MNT}}/dev/pts
mount -o bind,ro {,${MNT}}/sys
mount -o bind,ro {,${MNT}}/proc

# /tmp
mount -t tmpfs -o mode=1777 "${TMP}" "${MNT}${TMP}"

# Debug chroot when it's not working as expected
if [[ ! -z "${DEBUG_CHROOT}" ]]; then
	read -p "Press any key to test chroot ..."

	# set +e
	# set -x

	# From https://lists.nongnu.org/archive/html/qemu-discuss/2014-10/msg00046.html

	${MNT}${QEMU} --help > /dev/null || echo "You haven't installed the right QEMU into your chroot"

	chroot ${MNT} ${QEMU} --help > /dev/null || "Your allegedly static QEMU isn't actually statically linked"

	${MNT}${QEMU} ${MNT}/bin/ls > /dev/null && echo "Unnecessary usage of qemu?!" || :
	# this *should* fail with "/lib/ld-linux.so.3: No such file or directory"
	# or similar, indicating we read the executable but couldn't find
	# the dynamic linker. If this fails then maybe your chroot doesn't
	# have ARM binaries in it...

	chroot ${MNT} ${QEMU} /bin/ls > /dev/null || echo "Your chroot is likely wrongly set up"

	chroot ${MNT} /bin/ls > /dev/null || echo "Your binfmt-misc registration is broken. Check contents of /proc/sys/fs/binfmt_misc. Maybe run `sudo update-binfmts --enable`."
fi

if [[ ! -z "${EXEC}" ]]; then
	# Location in chroot that the executable will be run from
	EXEC_MNT=${TMP}/EXEC

	touch "${MNT}${EXEC_MNT}" # Don't need to cleanup. tmpfs

	# Mount instead of copying
	mount -o bind,ro "${EXEC}" "${MNT}${EXEC_MNT}"

	debug "Running ${EXEC} in ${MNT} chroot..."
	# Run the executable in Chroot
	chroot "${MNT}" "${EXEC_MNT}"
else
	debug "Chrooting..."
	chroot "${MNT}"
fi

# mount | tail

debug "Done!"

