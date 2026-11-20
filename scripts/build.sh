#!/bin/bash
set -e                  # exit on error
set -o pipefail         # exit on pipeline error
set -u                  # treat unset variable as error
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CMD=(setup_host debootstrap run_chroot build_iso)
DATE=`TZ="UTC" date +"%y%m%d-%H%M%S"`

function help() {
    if [ -z ${1+x} ]; then
        echo -e "This script builds a bootable RisOS 26.27 ISO image"
        echo -e
    else
        # SECURITY: quote and use printf - `echo -e $1` performed word
        # splitting and escape interpretation on untrusted input.
        printf '%b\n' "$1"
        echo
    fi
    echo -e "Supported commands : ${CMD[*]}"
    echo -e
    echo -e "Syntax: $0 [start_cmd] [-] [end_cmd]"
    echo -e "\trun from start_cmd to end_end"
    echo -e "\tif start_cmd is omitted, start from first command"
    echo -e "\tif end_cmd is omitted, end with last command"
    echo -e "\tenter single cmd to run the specific command"
    echo -e "\tenter '-' as only argument to run all commands"
    echo -e
    exit 0
}

function find_index() {
    local ret;
    local i;
    for ((i=0; i<${#CMD[*]}; i++)); do
        if [ "${CMD[i]}" == "$1" ]; then
            index=$i;
            return;
        fi
    done
    help "Command not found : $1"
}

function chroot_enter_setup() {
    sudo mount --bind /dev chroot/dev
    sudo mount --bind /run chroot/run
    sudo chroot chroot mount none -t proc /proc
    sudo chroot chroot mount none -t sysfs /sys
    sudo chroot chroot mount none -t devpts /dev/pts
}

function chroot_exit_teardown() {
    sudo chroot chroot umount -l /proc || true
    sudo chroot chroot umount -l /sys || true
    sudo chroot chroot umount -l /dev/pts || true
    sudo umount -l chroot/dev || true
    sudo umount -l chroot/run || true
}

function check_host() {
    local os_ver
    os_ver=`lsb_release -i | grep -E "(Ubuntu|Debian)"`
    if [[ -z "$os_ver" ]]; then
        echo "WARNING : OS is not Debian or Ubuntu and is untested"
    fi
    if [ $(id -u) -eq 0 ]; then
        echo "This script should not be run as 'root'"
        exit 1
    fi
}

function load_config() {
    if [[ -f "$SCRIPT_DIR/config.sh" ]]; then
        . "$SCRIPT_DIR/config.sh"
    elif [[ -f "$SCRIPT_DIR/default_config.sh" ]]; then
        . "$SCRIPT_DIR/default_config.sh"
    else
        >&2 echo "Unable to find default config file  $SCRIPT_DIR/default_config.sh, aborting."
        exit 1
    fi
}

function check_config() {
    local expected_config_version
    expected_config_version="0.5"
    if [[ "$CONFIG_FILE_VERSION" != "$expected_config_version" ]]; then
        >&2 echo "Invalid or old config version $CONFIG_FILE_VERSION, expected $expected_config_version. Please update your configuration file from the default."
        exit 1
    fi

    # SECURITY: fail fast on unsafe build parameters before anything is run
    # with root privileges. A plain-HTTP mirror allows a network attacker to
    # MITM debootstrap/apt and inject malicious packages into the ISO.
    if [[ ! "${TARGET_UBUNTU_MIRROR:-}" =~ ^https:// ]]; then
        >&2 echo "ERROR: TARGET_UBUNTU_MIRROR must use HTTPS (got: ${TARGET_UBUNTU_MIRROR:-unset}). Aborting for security reasons."
        exit 1
    fi
    # SECURITY: restrict the codename to a safe charset so it cannot be used
    # to inject extra apt/debootstrap options or sources.list lines.
    if [[ ! "${TARGET_UBUNTU_VERSION:-}" =~ ^[a-z]+$ ]]; then
        >&2 echo "ERROR: invalid TARGET_UBUNTU_VERSION: ${TARGET_UBUNTU_VERSION:-unset}"
        exit 1
    fi
}

function setup_host() {
    echo "=====> running setup_host ..."
    sudo apt update
    sudo apt install -y debootstrap squashfs-tools xorriso
    sudo mkdir -p chroot
}

function debootstrap() {
    echo "=====> running debootstrap ... will take a couple of minutes ..."
    sudo debootstrap --arch=amd64 --variant=minbase $TARGET_UBUNTU_VERSION chroot $TARGET_UBUNTU_MIRROR
}

function run_chroot() {
    echo "=====> running run_chroot ..."
    chroot_enter_setup
    
    # Setup build scripts in chroot environment
    sudo ln -f $SCRIPT_DIR/chroot_build.sh chroot/root/chroot_build.sh
    sudo ln -f $SCRIPT_DIR/default_config.sh chroot/root/default_config.sh
    if [[ -f "$SCRIPT_DIR/config.sh" ]]; then
        sudo ln -f $SCRIPT_DIR/config.sh chroot/root/config.sh
    fi

    # === Copy RisOS logos directly into chroot /root/ ===
    if [ -f "$SCRIPT_DIR/risos-logo.png" ]; then
        sudo cp "$SCRIPT_DIR/risos-logo.png" chroot/root/risos-logo.png
        echo "Copied risos-logo.png to chroot."
    fi
    if [ -f "$SCRIPT_DIR/risos-logo.svg" ]; then
        sudo cp "$SCRIPT_DIR/risos-logo.svg" chroot/root/risos-logo.svg
        echo "Copied risos-logo.svg to chroot."
    fi

    # Launch into chroot environment to build install image.
    sudo chroot chroot /usr/bin/env DEBIAN_FRONTEND=${DEBIAN_FRONTEND:-readline} /root/chroot_build.sh -
    
    # Cleanup after image changes
    sudo rm -f chroot/root/chroot_build.sh
    sudo rm -f chroot/root/default_config.sh
    sudo rm -f chroot/root/risos-logo.png
    sudo rm -f chroot/root/risos-logo.svg
    if [[ -f "chroot/root/config.sh" ]]; then
        sudo rm -f chroot/root/config.sh
    fi

    chroot_exit_teardown
}

function build_iso() {
    echo "=====> running build_iso ..."
    # move image artifacts
    sudo mv chroot/image .
    
    # compress rootfs
    sudo mksquashfs chroot image/casper/filesystem.squashfs \
        -noappend -no-duplicates -no-recovery \
        -wildcards \
        -comp xz -b 1M -Xdict-size 100% \
        -e "var/cache/apt/archives/*" \
        -e "root/*" \
        -e "root/.*" \
        -e "tmp/*" \
        -e "tmp/.*" \
        -e "swapfile"
        
    # write the filesystem.size
    printf $(sudo du -sx --block-size=1 chroot | cut -f1) | sudo tee image/casper/filesystem.size
    
    pushd $SCRIPT_DIR/image
    sudo xorriso \
        -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -J -J -joliet-long \
        -volid "$TARGET_NAME" \
        -output "$SCRIPT_DIR/$TARGET_NAME.iso" \
        -eltorito-boot isolinux/bios.img \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --eltorito-catalog boot.catalog \
        --grub2-boot-info \
        --grub2-mbr ../chroot/usr/lib/grub/i386-pc/boot_hybrid.img \
        -partition_offset 16 \
        --mbr-force-bootable \
        -eltorito-alt-boot \
        -no-emul-boot \
        -e isolinux/efiboot.img \
        -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b isolinux/efiboot.img \
        -appended_part_as_gpt \
        -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
        -m "isolinux/efiboot.img" \
        -m "isolinux/bios.img" \
        -e '--interval:appended_partition_2:::' \
        -exclude isolinux \
        -graft-points \
        "/EFI/boot/bootx64.efi=isolinux/bootx64.efi" \
        "/EFI/boot/mmx64.efi=isolinux/mmx64.efi" \
        "/EFI/boot/grubx64.efi=isolinux/grubx64.efi" \
        "/EFI/ubuntu/grub.cfg=isolinux/grub.cfg" \
        "/isolinux/bios.img=isolinux/bios.img" \
        "/isolinux/efiboot.img=isolinux/efiboot.img" \
        "."
    popd
}

# =============   main  ================
cd $SCRIPT_DIR
load_config
check_config
check_host

if [[ $# == 0 || $# > 3 ]]; then help; fi

dash_flag=false
start_index=0
end_index=${#CMD[*]}
for ii in "$@";
do
    if [[ $ii == "-" ]]; then
        dash_flag=true
        continue
    fi
    # SECURITY: validate the argument against the known command whitelist
    # before using it. The old code called `find_index $ii` unquoted and then
    # executed `${CMD[ii]}`, so an attacker-controlled argument (e.g. one
    # containing shell metacharacters or a subshell) could lead to arbitrary
    # code execution as root inside the chroot build pipeline.
    if ! printf '%s\n' "${CMD[@]}" | grep -Fxq -- "$ii"; then
        help "Command not found : $ii"
    fi
    find_index "$ii"
    if [[ $dash_flag == false ]]; then
        start_index=$index
    else
        end_index=$(($index+1))
    fi
done

if [[ $dash_flag == false ]]; then
    end_index=$(($start_index + 1))
fi

for ((ii=$start_index; ii<$end_index; ii++)); do
    ${CMD[ii]}
done

echo "$0 - Initial build is done!"
