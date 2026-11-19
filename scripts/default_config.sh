#!/bin/bash
# This script provides common customization options for the ISO
#
# Usage: Copy this file to config.sh and make changes there. Keep this file (default_config.sh) as-is
#   so that subsequent changes can be easily merged from upstream. Keep all customizations in config.sh

# The version of Ubuntu to generate. Successfully tested LTS: bionic, focal, jammy, noble
export TARGET_UBUNTU_VERSION="noble"

# The Ubuntu Mirror URL. It's better to change for faster download.
export TARGET_UBUNTU_MIRROR="http://archive.ubuntu.com/ubuntu/"

# The packaged version of the Linux kernel to install on target image.
export TARGET_KERNEL_PACKAGE="linux-generic"

# The file (no extension) of the ISO containing the generated disk image,
# the volume id, and the hostname of the live environment are set from this name.
export TARGET_NAME="risos"

# The text label shown in GRUB for booting into the live environment
export GRUB_LIVEBOOT_LABEL="Try RisOS 26.27 without installing"

# The text label shown in GRUB for starting installation
export GRUB_INSTALL_LABEL="Install RisOS 26.27"

# Packages to be removed from the target system after installation completes successfully
export TARGET_PACKAGE_REMOVE="
ubiquity \
casper \
discover \
laptop-detect \
os-prober \
"

# Package customisation function. Update this function to customize packages
# present on the installed system.
function customize_image() {
    # === FIX FOR FIREFOX SNAP ISSUE IN 24.04 ===
    # Добавляем официальный PPA Mozilla для классического .deb Firefox
    apt-get install -y software-properties-common
    add-apt-repository -y ppa:mozillateam/ppa
    
    # Настраиваем приоритет, чтобы apt выбирал .deb вместо snap-заглушки
    cat <<EOF > /etc/apt/preferences.d/mozilla-firefox
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
EOF
    
    # Создаем папку, если её нет, чтобы избежать ошибки "No such file or directory"
    mkdir -p /etc/apt/update-manager/release-upgrades.d/
    
    # Разрешаем автоматические обновления из этого PPA
    echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:${distro_codename}";' > /etc/apt/update-manager/release-upgrades.d/allow-mozillateam.cfg

    # install graphics and desktop (Noble compatible)
    apt-get install -y \
        plymouth-themes \
        ubuntu-desktop-minimal \
        ubuntu-wallpapers

    # Russian localization
    apt-get install -y \
        language-pack-ru \
        language-pack-gnome-ru \
        hunspell-ru \
        mythes-ru \
        hyphen-ru

    # User-friendly applications (NO dev tools)
    # Теперь firefox установится как нормальный deb-пакет!
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

    # === RisOS System Branding ===
    cat <<EOF > /etc/lsb-release
DISTRIB_ID=RisOS
DISTRIB_RELEASE=26.27
DISTRIB_CODENAME=noble
DISTRIB_DESCRIPTION="RisOS 26.27 LTS"
EOF

    sed -i 's/^NAME=.*/NAME="RisOS"/' /etc/os-release
    sed -i 's/^VERSION=.*/VERSION="26.27 LTS"/' /etc/os-release
    sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="RisOS 26.27 LTS"/' /etc/os-release
    sed -i 's/^ID=.*/ID=risos/' /etc/os-release
    sed -i 's|^HOME_URL=.*|HOME_URL="https://risos.org"|' /etc/os-release
    
    echo "risos" > /etc/hostname

    # === Replace Icons (Start Menu & Ubiquity) ===
    RISOS_PNG="/root/risos-logo.png"
    RISOS_SVG="/root/risos-logo.svg"
    
    # 1. GNOME Start Menu Icon (используем готовый SVG)
    START_HERE_ICON="/usr/share/icons/Yaru/scalable/actions/start-here-symbolic.svg"
    if [ -f "$RISOS_SVG" ] && [ -f "$START_HERE_ICON" ]; then
        cp "$RISOS_SVG" "$START_HERE_ICON"
        echo "GNOME start menu icon replaced with RisOS SVG logo."
    else
        echo "WARNING: risos-logo.svg or Yaru icon not found!"
    fi

    # 2. Ubiquity Installer Logo (используем цветной PNG)
    if [ -f "$RISOS_PNG" ]; then
        UBIQUITY_LOGO="/usr/share/ubiquity-slideshow/slides/ubuntu/images/logo.png"
        if [ -f "$UBIQUITY_LOGO" ]; then
            cp "$RISOS_PNG" "$UBIQUITY_LOGO"
            echo "Ubiquity slideshow logo replaced."
        fi
        
        UBIQUITY_HEADER_LOGO="/usr/share/pixmaps/ubuntu-logo-icon.png"
        if [ -f "$UBIQUITY_HEADER_LOGO" ]; then
            cp "$RISOS_PNG" "$UBIQUITY_HEADER_LOGO"
            echo "Ubiquity header logo replaced."
        fi
    else
        echo "WARNING: risos-logo.png not found for Ubiquity!"
    fi

    # Patch Ubiquity HTML slides text
    SLIDESHOW_DIR="/usr/share/ubiquity-slideshow/slides/ubuntu"
    if [ -d "$SLIDESHOW_DIR" ]; then
        find "$SLIDESHOW_DIR" -name "*.html" -exec sed -i 's/Ubuntu/RisOS 26.27/g' {} \;
        find "$SLIDESHOW_DIR" -name "*.html" -exec sed -i 's/ubuntu/risos/g' {} \;
    fi

    # purge unnecessary packages
    apt-get purge -y \
        transmission-gtk \
        transmission-common \
        gnome-mahjongg \
        gnome-mines \
        gnome-sudoku \
        aisleriot \
        hitori || true
}

# Used to version the configuration. If breaking changes occur, manual
# updates to this file from the default may be necessary.
export CONFIG_FILE_VERSION="0.4"
