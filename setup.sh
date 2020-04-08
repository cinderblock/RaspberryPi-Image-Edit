#!/bin/bash

# This is meant to be run on Raspbian to setup the env the way you want

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
ln -snf /usr/share/zoninfo/America/Los_Angeles /etc/localtime

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