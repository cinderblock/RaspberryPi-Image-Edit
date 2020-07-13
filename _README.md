# Usage

1. Download a Raspberry Pi OS image and unzip it: 
   ```bash
   wget https://downloads.raspberrypi.org/raspios_lite_armhf_latest --trust-server-names --timestamping --quiet
   unzip 2020-05-27-raspios-buster-lite-armhf.zip
   ```
2. Download gist files:
   ```bash
   wget https://gist.githubusercontent.com/cinderblock/20952a653989e55f8a7770a0ca2348a8/raw/{prepare,chroot,grow,setup}.sh --timestamping --quiet
   chmod +x {prepare,chroot,grow}.sh
   ```
3. Edit `setup.sh` as desired. *default adds **my** keys!*
4. Run scripts.

## Available scripts

```
sudo ./prepare.sh 2020-05-27-raspios-buster-lite-armhf.img [setup.sh] [mount point]
sudo ./chroot.sh 2020-05-27-raspios-buster-lite-armhf.img [mount point]
sudo ./grow.sh 2020-05-27-raspios-buster-lite-armhf.img [megabytes]
```

The default `setup.sh` script **will fail** unless you `grow` the standard `.img` first *(for 2020-02-13)*.

## Prepare

Runs the `setup.sh` (or other) script in a chroot in specified image.

## Chroot

Gives you a chroot in the image to change whatever manually.

**Planned changed:** Use `systemd-nspawn` instead of `chroot`.

Note: Bash history will be saved too. *Subject to change.*

## Grow

Grow the image (and main partition) by some number of megabytes.

This only affects the local `.img` file. On first boot, Raspbian will automatically grow the parition to fill the full card.

*Adding 100MB adds aproximately 10 seconds to the write time when transfering to an SD card.*

# See also

- https://github.com/RPi-Distro/pi-gen - Full featured `.img` generator
- https://gist.github.com/htruong/0271d84ae81ee1d301293d126a5ad716 - Instructions to grow and chroot
- https://gist.github.com/htruong/7df502fb60268eeee5bca21ef3e436eb - Script to just mount & chroot (no loopback)
- https://gist.github.com/kmdouglass/38e1383c7e62745f3cf522702c21cb49 - Script: loopback, mount, chroot. No cleanup.
