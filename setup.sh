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

echo Setting up...

# Prepare setup script. These are the commands that will actually be run on the image
cat <<EOF > ${MNT}/setup.sh
#!/bin/bash

set -e

# Set locale to US
echo en_US.UTF-8 UTF-8 > /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

# Initialize Authorized Keys
mkdir -p /home/pi/.ssh
chown pi: /home/pi/.ssh
curl -q https://github.com/cinderblock.keys > /home/pi/.ssh/authorized_keys
chown pi: /home/pi/.ssh/authorized_keys

# Enable SSHD, without passwords
systemctl enable ssh
echo PasswordAuthentication no >> /etc/ssh/sshd_config

# Add WiFi config
cat << EOF_WPA > /etc/wpa_supplicant/wpa_supplicant.conf
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
  ssid="My SSID"
  psk="My PSK"
}
EOF_WPA

# Set Hostname
sed -e s/raspberrypi/myHostname/ -i /etc/host{s,name}

# Set Timezone
timedatectl set-timezone America/Los_Angeles

# Update
apt-get update
apt-get upgrade -y

# Install Essentials
apt-get install vim screen git -y
echo "caption always '%{= dg} %H %{G}| %{B}%l %{G}|%=%?%{d}%-w%?%{r}(%{d}%n %t%? {%u} %?%{r})%{d}%?%+w%?%=%{G}| %{B}%M %d %c:%s '" >> /etc/screenrc

# Install Node.js (needs and extra 50MB of space on the 2020-02-13 image first! See "Grow Image")
curl -sL https://deb.nodesource.com/setup_12.x | bash -
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list
apt-get install -y nodejs yarn

# Optional set passwd for user `pi`
# passwd pi
EOF

# Make out setup script executable
chmod +x ${MNT}/setup.sh

# Run the script in Chroot
chroot ${MNT} /setup.sh

echo Cleaning up...

# cleanup script
rm ${MNT}/setup.sh

# Full reset
sudo umount ${MNT}${QEMU}
sudo rm ${MNT}${QEMU}
sudo sed -i 's/^#QEMU //g' ${MNT}/etc/ld.so.preload
sudo umount ${MNT}{/{boot,dev{/pts,},sys,proc},}
sudo losetup -d ${LOOP}
