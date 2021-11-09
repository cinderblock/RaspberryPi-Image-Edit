#!/bin/bash

# This is meant to be run on Raspberry Pi OS to setup the system the way you want.

## Freeform Options
TIMEZONE="America/Los_Angeles"
PACKAGES="git"
LOCALE="en_US.UTF-8 UTF-8"
PASSWORD_PI="blueberry"
KEYS_GH="cinderblock"

## Binary Options
# Make sure these are `true` or `false`

# For Pi Zero
ARM6=true

# Node.js
NODE_INSTALL=true

NODE_USE_LTS=true

NODE_USE_UNOFFICIAL=${ARM6}
# Use the official (long and slow) install script?
NODE_USE_NODESOURCE_INSTALL_SCRIPT=false

NODE_UPDATE_NPM=true

# GNU Screen
SCREEN_INSTALL=true
SCREEN_HARDSTATUS=true

# Python 3
PYTHON3_INSTALL=true
PYTHON3_DEFAULT=true

# Vim
VIM_INSTALL=true
VIM_DEFAULT=true

### END OF VARIABLES

# If any error happens, why try to continue. Bubble the error.
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

function addPackages {
	PACKAGES+=" $@"
}

trap error ERR

# Set locale to US

if [[ ! -z ${LOCALE} ]]; then
debug "Locale..."
echo en_US.UTF-8 UTF-8 > /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8
# From raspi-config
#echo "$LOCALE $ENCODING" > /etc/locale.gen
#sed -i "s/^\s*LANG=\S*/LANG=$LOCALE/" /etc/default/locale
#dpkg-reconfigure -f noninteractive locales
fi

if [[ ! -z ${KB_LAYOUT} ]]; then
# TODO: Setup keyboard layout
# raspi-config:
#sed -i /etc/default/keyboard -e "s/^XKBLAYOUT.*/XKBLAYOUT=\"$KEYMAP\"/"
#dpkg-reconfigure -f noninteractive keyboard-configuration
:
fi

if [[ ! -z ${PASSWORD_PI} ]]; then
# Set password
debug "Seting Pi's Password..."
# Set directly, no promt, in plaintext
echo "pi:${PASSWORD_PI}" | chpasswd
# Ask for the new password mid script
#passwd pi
fi

if [[ ! -z ${KEYS_GH} ]]; then
# Add SSH keys
debug "Keys..."
sudo -u pi bash -e << EOF_PI
	mkdir -p ~/.ssh
	curl -sL https://github.com/${KEYS_GH}.keys > ~/.ssh/authorized_keys
	echo "sudo raspi-config" > ~/.bash_history
EOF_PI
# TODO: pull out the "raspi-config" from this if block
fi

# Enable SSHD, without passwords
debug "Enable SSH..."
systemctl enable ssh
echo PasswordAuthentication no >> /etc/ssh/sshd_config

# Add WiFi config
debug "WiFi Example..."
cat <<- EOF_WPA > /boot/wpa_supplicant.conf
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
cat <<- 'EOF_HOSTNAME' > /etc/systemd/system/hostname-switch.service
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
	ExecStart=/bin/sh -c 'echo 127.0.1.1\\\t$(hostname) >> /etc/hosts'
	# Reset hostname file in /boot
	ExecStart=/usr/bin/truncate -s 0 /boot/hostname

	[Install]
	WantedBy=multi-user.target
EOF_HOSTNAME
touch /boot/hostname
systemctl enable hostname-switch.service

# Boot README
debug "Adding README to /boot"
cat <<- 'EOF_README' > /boot/README.md
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
debug "Setting Timezone to: ${TIMEZONE}"
debug "Before: $(date)"
ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
debug "After : $(date)"

if $NODE_INSTALL; then
	debug "Installing Node.js..."

	if $NODE_USE_UNOFFICIAL; then
		debug "Using unofficial Node.js builds..."

		if $NODE_USE_LTS; then
			DOWNLOAD_VERSION=$(curl -Ls https://unofficial-builds.nodejs.org/download/release/index.tab | tail -n+2 | awk '$10!="-"' - | head -n 1 | cut -f 1)
		else
			DOWNLOAD_VERSION=$(curl -Ls https://unofficial-builds.nodejs.org/download/release/index.tab | tail -n+2 | head -n1 | cut -f 1)
		fi

		DOWNLOAD_URL=https://unofficial-builds.nodejs.org/download/release/${DOWNLOAD_VERSION}/node-${DOWNLOAD_VERSION}-linux-armv6l.tar.xz

		curl -sL "${DOWNLOAD_URL}" | tar xJ -C /usr/local --strip-components=1
	else
		# TODO: Fully respect optional `NODE_VERSION` environment variable
		if $NODE_USE_LTS; then
			NODE_DOWNLOAD_NODESOURCE_URL=https://deb.nodesource.com/setup_lts.x
		else
			NODE_DOWNLOAD_NODESOURCE_URL=https://deb.nodesource.com/setup_current.x
		fi

		if $NODE_USE_NODESOURCE_INSTALL_SCRIPT; then
			debug "Using official Nodesource installer script"
			curl -sL ${NODE_DOWNLOAD_NODESOURCE_URL} --retry 1 | bash -
		else
			debug "Manually adding Nodesource to apt"
			if [[ -z "$NODE_VERSION" ]]; then
				NODE_VERSION=$(curl -sL ${NODE_DOWNLOAD_NODESOURCE_URL} --retry 1 | grep NODEREPO= | sed -E 's/^NODEREPO="([^"]+)"$/\1/g')
			fi

			curl -sL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor > /usr/share/keyrings/nodesource.gpg
			cat <<- EOF_NODE > /etc/apt/sources.list.d/nodesource.list
				deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/${NODE_VERSION} buster main
				deb-src [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/${NODE_VERSION} buster main
			EOF_NODE

			addPackages nodejs
		fi
	fi
fi

if $PYTHON3_INSTALL; then
	addPackages python3{,-pip}
fi

if $PIGPIO_API; then
	addPackages libpigpio-dev
	if $PIGPIO_NODE_HACK; then
		# Workaround bad node-pigpio issues
		ln -snf /usr/bin/false /usr/local/bin/pigpiod
	fi
elif $PIGPIO_DAEMON; then
	addPackages pigpiod
fi

# Update
debug "Update"
apt-get -qq update

debug "Upgrade"
apt-get -qq upgrade -y --auto-remove

# Install Essentials
debug "Installing Packages: ${PACKAGES}"
apt-get -qq install -y --auto-remove ${PACKAGES}

if $NODE_INSTALL; then
if $NODE_UPDATE_NPM; then
	debug "Update Npm"
	npm install --global npm
fi

if $NODE_INSTALL_YARN; then
	debug "Installing Yarn"
	npm install --global yarn
fi
fi

if $SCREEN_INSTALL && $SCREEN_HARDSTATUS; then
debug "Add nice caption to GNU screen"
# This is a nice colorful "status" line that shows which tab you're on in screen. You're welcome ;)
echo "caption always '%{= dg} %H %{G}| %{B}%l %{G}|%=%?%{d}%-w%?%{r}(%{d}%n %t%? {%u} %?%{r})%{d}%?%+w%?%=%{G}| %{B}%M %d %c:%s '" >> /etc/screenrc
fi

if $VIM_INSTALL && $VIM_DEFAULT; then
debug "Set default editor to Vim"
#update-alternatives --set editor /usr/bin/vim.basic
# Instead of "manually" setting vim as our editor, set nano to a much lower priority than normal
update-alternatives --install /usr/bin/editor editor /bin/nano 10
fi

if $PYTHON3_INSTALL && $PYTHON3_DEFAULT; then
debug "Set python default version to 3"
update-alternatives --install /usr/bin/python python /usr/bin/python3 3
update-alternatives --install /usr/bin/python python /usr/bin/python2 2
fi

debug "apt clean"
# apt-get -qq clean

debug "Done!"

df -h /
