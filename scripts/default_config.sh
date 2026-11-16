# Версия и имя
export TARGET_NAME="risos"
export GRUB_LIVEBOOT_LABEL="Try RisOS 26.27 without installing"
export GRUB_INSTALL_LABEL="Install RisOS 26.27"

# В функции customize_image() добавляем подмену branding-файлов GNOME:
function customize_image() {
    # ... существующие пакеты ...

    # === RisOS Branding ===
    # Создаём директорию для иконки меню Пуск
    mkdir -p /usr/share/risos/icons
    
    # Подмена названия в "О системе" (GNOME Settings)
    # В Noble это делается через dconf/gsettings или патчинг .desktop файлов
    # Самый надёжный способ — создать override для gnome-control-center
    mkdir -p /etc/dconf/db/local.d
    cat <<EOF > /etc/dconf/db/local.d/00-risos-branding
[org/gnome/settings-daemon/plugins/media-keys]
# Можно добавить кастомные горячие клавиши при необходимости
EOF

    # Патчим lsb-release для корректного отображения версии
    cat <<EOF > /etc/lsb-release
DISTRIB_ID=RisOS
DISTRIB_RELEASE=26.27
DISTRIB_CODENAME=noble
DISTRIB_DESCRIPTION="RisOS 26.27 LTS"
EOF

    # Патчим os-release (используется современными приложениями)
    sed -i 's/^NAME=.*/NAME="RisOS"/' /etc/os-release
    sed -i 's/^VERSION=.*/VERSION="26.27 LTS"/' /etc/os-release
    sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="RisOS 26.27 LTS"/' /etc/os-release
    sed -i 's/^ID=.*/ID=risos/' /etc/os-release
    sed -i 's|^HOME_URL=.*|HOME_URL="https://risos.org"|' /etc/os-release
    sed -i 's|^SUPPORT_URL=.*|SUPPORT_URL="https://risos.org/support"|' /etc/os-release
    sed -i 's|^BUG_REPORT_URL=.*|BUG_REPORT_URL="https://risos.org/bugs"|' /etc/os-release

    # Обновляем hostname
    echo "risos" > /etc/hostname
    sed -i 's/uksus-os/risos/g' /etc/hosts 2>/dev/null || true
}
