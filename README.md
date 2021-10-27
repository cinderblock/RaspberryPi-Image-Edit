# Setup Raspberry Pi OS Image Script

Scripts for modifying Raspberry Pi OS images **before** writing to SD card.

## Easy Mode

```bash
git clone https://github.com/cinderblock/RaspberryPi-Image-Generator.git
cd RaspberryPi-Image-Generator
# Edit `setup.sh`. This gist adds *my* keys!
./new.sh
```

## Manual Mode

1. Download a Raspberry Pi OS image and unzip it:
   ```bash
   wget https://downloads.raspberrypi.org/raspios_lite_armhf_latest --trust-server-names --timestamping --quiet
   unzip *-*-*-raspios-buster-lite-armhf.zip
   ```
2. Download gist files:
   ```bash
   wget https://raw.githubusercontent.com/cinderblock/RaspberryPi-Image-Generator/master/{setup,chroot,grow,new}.sh --timestamping --quiet
   chmod +x {setup,chroot,grow,new}.sh
   ```
3. Edit `setup.sh` as desired. *default adds **my** keys!*
4. Run scripts.

## Available scripts

```bash
sudo ./chroot.sh 2020-05-27-raspios-buster-lite-armhf.img [executable] [mount point]
sudo ./grow.sh 2020-05-27-raspios-buster-lite-armhf.img [megabytes]
./new.sh [image-path]
# `setup.sh` is meant to be run on a Raspberry Pi image in a chroot.
sudo ./edit-boot.sh 2020-05-27-raspios-buster-lite-armhf.img
./get-latest.sh
```

The default `setup.sh` script **will fail** unless you `grow` the standard `.img` by ~400MB first *(as of 2021-07-15)*.

Runs the `setup.sh` (or other) script in a chroot in specified image.

### Chroot

Gives you a chroot in the image to change whatever manually.

```bash
 ./chroot.sh my-raspios.img
 ```

 *If anything goes wrong, the script should cleanup after itself and not leave dangling mounts or loopback devices.*

**Planned changed:** Use `systemd-nspawn` instead of `chroot`.

Maintains a separate "`.bash_history`" that is re-used for all images in a `.persist` folder.
This behavior can be overridden by setting `LEAVE_HISTORY_ALONE=yes` (any non-zero length string).

### Prepare

The `./chroot.sh` script can also be run in "prepare" mode.
Give it a second argument of an executable to run inside the chrooted environment as root.
For example: `./chroot.sh my-raspios.img some-executable`.

### Grow

Grow the image (and main partition) by some number of megabytes.

```bash
 ./grow.sh my-raspios.img 400
 ```

This only affects the local `.img` file. On first boot, Raspbian will automatically grow the parition to fill the full card.

*Adding 100MB adds aproximately 10 seconds to the write time when transfering to an SD card.*

### New

Does all the steps needed to get a brand new image in a single command.
Assumes other scripts are in the same folder.

```bash
./new.sh
```

The steps are:

1. Download a new `img` file
2. `unzip` it on the fly
3. Save to a custom img file (overwritting if it exists)
4. Grows the image
5. Runs `setup.sh` inside the `chroot`
6. Zips the img to save space

### Setup

This script is meant to be run inside a raspberry pi chroot, as root.

It might run succesfully running directly on a Pi, but that is not a supported use case.

#### Current Features

- Adds ssh keys
- Enables sshd, without passwords
- Sets US locale
- Adds WiFi configuration to `/boot`
- Adds a new script to change a Pi's hostname with a file `/boot/hostname`
- Sets timezone to `America/Los_Angeles`
- Updates & Upgrades
- Installs `git`, `vim`, `screen`, and `node`
- Sets the passwd for `pi`
- Sets `python3` as the default Python version
- Sets `vim` as the default editor

### Edit Boot `get-boot.sh`

A simplified mounting of the filesystem that only accesses the image's `/boot` parition.

### Get Latest `get-latest.sh`

Download the official latest version of raspios-lite.
Don't overwrite if it already exists.
Continue downloading if previously interrupted.

## See also

- https://github.com/RPi-Distro/pi-gen - Full featured `.img` generator
- https://wiki.debian.org/RaspberryPi/qemu-user-static - Debian instructions to grow/mount/chroot/qemu-run
- https://gist.github.com/htruong/0271d84ae81ee1d301293d126a5ad716 - Instructions to grow and chroot
- https://gist.github.com/htruong/7df502fb60268eeee5bca21ef3e436eb - Script to just mount & chroot (no loopback)
- https://gist.github.com/kmdouglass/38e1383c7e62745f3cf522702c21cb49 - Script: loopback, mount, chroot. No cleanup.
