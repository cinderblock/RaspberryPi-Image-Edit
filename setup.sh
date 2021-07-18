#!/bin/bash

# This is meant to be run on Raspberry Pi OS to setup the system the way you want.
# No variables to change. Just change what you want to change.
# For instance, the default gives *me* access to your system!

set -e


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

PREFIX="${GREEN}SETUP${NC}"

function debug {
  echo -e "${PREFIX}" "$@"
}

function error {
  echo -e "${PREFIX}" "${RED}ERROR ABOVE${NC}"
  echo -e "${PREFIX}" "Maybe we ran out of space??"
  df -h /
}

trap error ERR

# Set locale to US
debug "Locale..."
echo en_US.UTF-8 UTF-8 > /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8
# From raspi-config
#echo "$LOCALE $ENCODING" > /etc/locale.gen
#sed -i "s/^\s*LANG=\S*/LANG=$LOCALE/" /etc/default/locale
#dpkg-reconfigure -f noninteractive locales

# TODO: Setup keyboard layout
# raspi-config:
#sed -i /etc/default/keyboard -e "s/^XKBLAYOUT.*/XKBLAYOUT=\"$KEYMAP\"/"
#dpkg-reconfigure -f noninteractive keyboard-configuration

# Set password
debug "Seting Pi's Password..."
# Set directly, no promt, in plaintext
echo "pi:password" | chpasswd
# Ask for the new password mid script
#passwd pi

# Add SSH keys
debug "Keys..."
sudo -u pi bash -e <<EOF_PI
mkdir -p ~/.ssh
curl -sL https://github.com/cinderblock.keys > ~/.ssh/authorized_keys
echo "sudo raspi-config" > ~/.bash_history
EOF_PI

# Enable SSHD, without passwords
debug "Enable SSH..."
systemctl enable ssh
echo PasswordAuthentication no >> /etc/ssh/sshd_config

# Add WiFi config
debug "WiFi Example..."
cat << EOF_WPA > /boot/wpa_supplicant.conf
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
  ssid="My SSID"
  psk="My PSK"
}
EOF_WPA

# Hostname
debug "Hostname setting system..."
cat << 'EOF_HOSTNAME' > /etc/systemd/system/hostname-switch.service
[Unit]
Description=Change hostname by /boot file
ConditionFileNotEmpty=/boot/hostname
Before=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
RemainAfterExit=yes
# Print current hostname for logs
ExecStart=/usr/bin/hostname
# Copy hostname file
ExecStart=/bin/cp /boot/hostname /etc/hostname
# Ensure file ends with a newline
ExecStart=/usr/bin/sed -i -e $$a\\ /etc/hostname
# Set hostname from file
ExecStart=/usr/bin/hostname -F /etc/hostname
# Remove default hostname from /etc/hosts
ExecStart=/usr/bin/sed -i.orig -E /^127.0.1.1\\s+raspberrypi\\s*$$/d /etc/hosts
# Add new hostname to /etc/hosts
ExecStart=/bin/sh -c 'echo 127.0.1.1\\t$(hostname) >> /etc/hosts'
# Reset hostname file in /boot
ExecStart=/usr/bin/truncate -s 0 /boot/hostname

[Install]
WantedBy=multi-user.target
EOF_HOSTNAME
touch /boot/hostname

# Boot README
debug "Adding README to /boot"
cat << 'EOF_README' > /boot/README.md
# Raspberry Pi /boot directory

Control boot options of Raspberry Pi.

See: https://www.raspberrypi.org/documentation/configuration/boot_folder.md

## Hostname (not official)

Create a file `hostname` with a single line that is the new hostname to use on boot.

## WPA Supplicant

Create a file `wpa_supplicant.conf` to update the WiFi configuration on boot.

Example:

```conf
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
  ssid="My SSID"
  psk="My PSK"
}
```

## `cmdline.txt`

Kernel boot options.

See: https://www.raspberrypi.org/documentation/configuration/cmdline-txt.md

## `config.txt`

Hardware boot configuration.

See: https://www.raspberrypi.org/documentation/configuration/config-txt/README.md
EOF_README

# Set Timezone
TIMEZONE=America/Los_Angeles
debug "Setting Timezone to: ${TIMEZONE}"
debug "Before: $(date)"
ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
debug "After : $(date)"

# Add Node.js sources
debug "Add Node.js Sources..."
#curl -sL https://deb.nodesource.com/setup_lts.x | bash -
curl -sL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor > /usr/share/keyrings/nodesource.gpg
NODE_VERSION=$(curl -sL https://deb.nodesource.com/setup_lts.x --retry 1 | grep NODEREPO= | sed -E 's/^NODEREPO="([^"]+)"$/\1/g')
cat << EOF_NODE > /etc/apt/sources.list.d/nodesource.list
deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/${NODE_VERSION} buster main
deb-src [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/${NODE_VERSION} buster main
EOF_NODE

# Update
debug "Update"
apt-get -qq update

debug "Upgrade"
apt-get -qq upgrade -y --auto-remove

# Install Essentials
debug "Packages"
apt-get -qq install -y --auto-remove vim screen git python3{,-pip} nodejs

debug "Set sensible defaults..."

# This is a nice colorful "status" line that shows which tab you're on in screen. You're welcome ;)
echo "caption always '%{= dg} %H %{G}| %{B}%l %{G}|%=%?%{d}%-w%?%{r}(%{d}%n %t%? {%u} %?%{r})%{d}%?%+w%?%=%{G}| %{B}%M %d %c:%s '" >> /etc/screenrc

# Set default editor
#update-alternatives --set editor /usr/bin/vim.basic
# Instead of "manually" setting vim as our editor, set nano to a much lower priority than normal
update-alternatives --install /usr/bin/editor editor /bin/nano 10

# Set python default version
update-alternatives --install /usr/bin/python python /usr/bin/python3 3
update-alternatives --install /usr/bin/python python /usr/bin/python2 2

# apt-get -qq clean

debug "Done!"

df -h /