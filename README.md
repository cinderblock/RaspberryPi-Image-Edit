# Setup Raspbian Image

First, download an image and unzip it: 

```bash
wget -q https://downloads.raspberrypi.org/raspbian_lite_latest --trust-server-names -c
unzip 2020-02-13-raspbian-buster-lite.zip
```

Now, we can use scripts:

```
sudo ./setup.sh 2020-02-13-raspbian-buster-lite.img [mount point]
sudo ./chroot.sh 2020-02-13-raspbian-buster-lite.img [mount point]
sudo ./grow.sh 2020-02-13-raspbian-buster-lite.img [megabytes]
```