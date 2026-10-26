#!/bin/bash
export TARGET_UBUNTU_VERSION="focal"
export TARGET_UBUNTU_MIRROR="http://us.archive.ubuntu.com/ubuntu/"
export TARGET_KERNEL_PACKAGE="linux-generic"
export TARGET_NAME="uksus-os"
export GRUB_LIVEBOOT_LABEL="Try Uksus OS without installing"
export GRUB_INSTALL_LABEL="Install Uksus OS"
export TARGET_PACKAGE_REMOVE="
ubiquity \
casper \
discover \
laptop-detect \
os-prober \
"
function customize_image() {
apt-get install -y \
plymouth-themes \
ubuntu-gnome-desktop \
ubuntu-gnome-wallpapers
apt-get install -y \
language-pack-ru \
language-pack-gnome-ru \
hunspell-ru \
mythes-ru \
hyphen-ru
apt-get install -y \
clamav-daemon \
terminator \
apt-transport-https \
curl \
vim \
nano \
less
update-locale LANG=ru_RU.UTF-8 LANGUAGE=ru:en LC_ALL=ru_RU.UTF-8
apt-get purge -y \
transmission-gtk \
transmission-common \
gnome-mahjongg \
gnome-mines \
gnome-sudoku \
aisleriot \
hitori
}
export CONFIG_FILE_VERSION="0.4"
