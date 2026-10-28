#!/bin/bash
# This script provides common customization options for the ISO
#
# Usage: Copy this file to config.sh and make changes there.  Keep this file (default_config.sh) as-is
#   so that subsequent changes can be easily merged from upstream.  Keep all customiations in config.sh

# The version of Ubuntu to generate.  Successfully tested LTS: bionic, focal, jammy, noble
# See https://wiki.ubuntu.com/DevelopmentCodeNames for details
export TARGET_UBUNTU_VERSION="focal"

# The Ubuntu Mirror URL. It's better to change for faster download.
# More mirrors see: https://launchpad.net/ubuntu/+archivemirrors
export TARGET_UBUNTU_MIRROR="http://us.archive.ubuntu.com/ubuntu/"

# The packaged version of the Linux kernel to install on target image.
# See https://wiki.ubuntu.com/Kernel/LTSEnablementStack for details
export TARGET_KERNEL_PACKAGE="linux-generic"

# The file (no extension) of the ISO containing the generated disk image,
# the volume id, and the hostname of the live environment are set from this name.
export TARGET_NAME="uksus-os"

# The text label shown in GRUB for booting into the live environment
export GRUB_LIVEBOOT_LABEL="Try Uksus OS without installing"

# The text label shown in GRUB for starting installation
export GRUB_INSTALL_LABEL="Install Uksus OS"

# Packages to be removed from the target system after installation completes succesfully
export TARGET_PACKAGE_REMOVE="
ubiquity \
casper \
discover \
laptop-detect \
os-prober \
"

# Package customisation function.  Update this function to customize packages
# present on the installed system.
function customize_image() {
    # install graphics and desktop
    apt-get install -y \
        plymouth-themes \
        ubuntu-gnome-desktop \
        ubuntu-gnome-wallpapers

    # Russian localization
    apt-get install -y \
        language-pack-ru \
        language-pack-gnome-ru \
        hunspell-ru \
        mythes-ru \
        hyphen-ru

    # User-friendly applications (NO dev tools)
    apt-get install -y \
        firefox \
        gnome-calculator \
        gnome-text-editor \
        eog \
        evince \
        file-roller \
        gnome-system-monitor

    # Set Russian locale as default
    update-locale LANG=ru_RU.UTF-8 LANGUAGE=ru:en LC_ALL=ru_RU.UTF-8

    # purge unnecessary packages
    apt-get purge -y \
        transmission-gtk \
        transmission-common \
        gnome-mahjongg \
        gnome-mines \
        gnome-sudoku \
        aisleriot \
        hitori
}

# Used to version the configuration.  If breaking changes occur, manual
# updates to this file from the default may be necessary.
export CONFIG_FILE_VERSION="0.4"
