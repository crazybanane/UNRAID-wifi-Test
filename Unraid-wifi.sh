#!/bin/bash

# Install dependencies

mkdir /boot/packages

function install_dep {
  printf "Dependency $1: "
  rm /boot/packages/$1.txz &>/dev/null
  wget -O /boot/packages/$1.txz https://mirrors.slackware.com/slackware/slackware64-current/slackware64/$2 &>/dev/null
  printf "downloaded "
  installpkg /boot/packages/$1.txz &>/dev/null
  printf "installed\n"
}

install_dep bc ap/bc-1.07.1-x86_64-6.txz
install_dep binutils d/binutils-2.42-x86_64-1.txz
install_dep cpio a/cpio-2.15-x86_64-1.txz
install_dep gc l/gc-7.4.2-x86_64-3.txz
install_dep gcc d/gcc-14.1.0-x86_64-1.txz
install_dep git d/git-2.45.0-x86_64-1.txz
install_dep glibc l/glibc-2.39-x86_64-2.txz
install_dep infozip a/infozip-6.0-x86_64-3.txz
install_dep kernel-headers d/kernel-headers-6.9.0-x86-1.txz
install_dep guile d/guile-3.0.9-x86_64-2.txz
install_dep libmpc l/libmpc-1.3.1-x86_64-1.txz
install_dep make d/make-4.4.1-x86_64-1.txz
install_dep ncurses l/ncurses-6.5-x86_64-1.txz
install_dep perl d/perl-5.38.2-x86_64-2.txz

# Build kernel

cd /tmp
wget https://www.kernel.org/pub/linux/kernel/v6.x/linux-6.9.0.tar.gz
tar -C /usr/src/ -zxvf linux-6.9.0.tar.gz
ln -sf /usr/src/linux-6.9.0 /usr/src/linux
cp -rf /usr/src/linux-6.9.0-unRAID/* /usr/src/linux/
cp -f /usr/src/linux-6.9.0-unRAID/.config /usr/src/linux/

cd /usr/src/linux
git apply *.patch
make oldconfig

echo "
In the next step you will be presented with menuconfig.
You will need to choose cfg80211, cfg80211 wireless extensions, mac80211 and RF switch (rfkill):

[*] Networking support
-*-   Wireless
<M>     cfg80211 - wireless configuration API
[ ]       nl80211 testmode command (NEW)
[ ]       enable developer warnings (NEW)
[*]       enable powersave by default (NEW)
[*]       cfg80211 wireless extensions compatibility
<M>     Generic IEEE 802.11 Networking Stack (mac80211)
        Default rate control algorithm (Minstrel)
[ ]     Enable mac80211 mesh networking (pre-802.11s) support (NEW)
[ ]     Trace all mac80211 debug messages (NEW)
[ ]     Select mac80211 debugging features (NEW)
<M>   RF switch subsystem support
"
read -p "Press Enter to continue."
make menuconfig
make clean
make -j12 headers_install INSTALL_HDR_PATH=/usr
make -j12
make -j12 modules_install
make -j12 firmware_install

# Build RTL8812AU driver

rm -R /tmp/rtl8812au &>/dev/null
git clone https://github.com/zebulon2/rtl8812au-driver-5.2.9 /tmp/rtl8812au
cd /tmp/rtl8812au
make clean
make -j12
gzip 8812au.ko
mkdir /lib/modules/6.9.0-unRAID/kernel/drivers/net/wireless
chmod 755 /lib/modules/6.9.0-unRAID/kernel/drivers/net/wireless
cp 8812au.ko.gz /lib/modules/6.9.0-unRAID/kernel/drivers/net/wireless/
chmod 644 /lib/modules/6.9.0-unRAID/kernel/drivers/net/wireless/8812au.ko.gz
depmod -a

# Create new bzroot and bzimage

rm -R /tmp/bz &>/dev/null
mkdir /tmp/bz
cd /tmp/bz
xzcat /boot/bzroot | cpio -m -i -d -H newc --no-absolute-filenames
rsync -av --delete /lib/modules/6.9.0-unRAID/ lib/modules/6.9.0-unRAID/
cd /tmp/bz/lib/modules/6.9.0-unRAID
rm build
rm source
ln -sf /usr/src/linux-6.9.0-unRAID build
ln -sf /usr/src/linux-6.9.0-unRAID source
cd /tmp/bz
find . | cpio -o -H newc | xz --check=crc32 --x86 --lzma2=preset=9e > /boot/bzroot-custom
cp /usr/src/linux/arch/x86/boot/bzImage /boot/bzimage-custom
