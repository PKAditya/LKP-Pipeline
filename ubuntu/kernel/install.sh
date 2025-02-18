#!/bin/bash

LOCAL_VERSION=$1
build_home=$2
# log handling
log="$build_home/lkp-automation-data/logs/pre-reboot-log"
log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $log
}
handle_error() {
    log "ERROR: $1"
    echo "SETUP Failed, refer $log for the details"
    exit 1
}

# Building the configured kernel
log "Intiated kernel build"
yes "" | make -j$(nproc) || handle_error "Failed to build kernel"
log "Successfully built the kernel"


# Building the deb-pkg for the built kernel
log "Building debian package for the built kernel...."
make bindeb-pkg -j$(nproc) || handle_error "Building Debian package failed."
log "Successfully built the debian package"
KERNEL_PACKAGE=$(find .. -name "linux-image-[0-9]*-auto-base*.deb" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" ") || handle_error "Cannot find kernel with the mentioned specifications. Kernel finding failed."

log "Copying the kernel package to $build_home/lkp-automation-data/PACKAGES for further purposes"
cp $KERNEL_PACKAGE $build_home/lkp-automation-data/PACKAGES


echo "////////////////////KERNEL_VERSION: $KERNEL_PACKAGE////////////////////////"

log "Installing the built deb package"
dpkg -i "$KERNEL_PACKAGE" || handle_error "Failed to install the $KERNEL_PACKAGE deb package"
log "Installed the built deb package"

touch $build_home/lkp-automation-data/state-files/kernel-package
echo "$KERNEL_PACKAGE" > $build_home/lkp-automation-data/state-files/kernel-package

log "Extracting kernel version"
KERNEL_VERSION=$(dpkg-deb -f "$KERNEL_PACKAGE" Version | cut -d'-' -f1) || handle_error "Couldn't capture the installed deb version"
log "Captured kernel version: $KERNEL_VERSION"

rm $build_home/lkp-automation-data/state-files/kernel-version &> /dev/null
touch $build_home/lkp-automation-data/state-files/kernel-version
echo "$KERNEL_VERSION" > $build_home/lkp-automation-data/state-files/kernel-version

echo "version: $KERNEL_VERSION"

# Update GRUB to use new kernel
log "Updating GRUB configuration"
update-grub || handle_error "Failed to update GRUB configuration"

# Set the new kernel as default by modifying GRUB_DEFAULT
KERNEL_PATH=$(find /boot -name "vmlinuz-$KERNEL_VERSION*" -type f | head -n1)
if [ -n "$KERNEL_PATH" ]; then
    MENU_ENTRY=$(grep -A1 "menuentry .*$(basename $KERNEL_PATH)" /boot/grub/grub.cfg | head -n1 | cut -d"'" -f2)
    if [ -n "$MENU_ENTRY" ]; then
        sed -i "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=\"$MENU_ENTRY\"/" /etc/default/grub
        update-grub || handle_error "Failed to update GRUB after setting default kernel"
    else
        handle_error "Could not find GRUB menu entry for new kernel"
    fi
else
    handle_error "Could not find new kernel in /boot"
fi

log "Going out of debian/kernel/install.sh script"


