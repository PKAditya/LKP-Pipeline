#!/bin/bash

echo "DIR:$1"
echo "name:$2"
KERNEL_DIR=$1
name=$2
build_home=$3

log="$build_home/lkp-automation-data/logs/pre-reboot-log"
log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $log
}
handle_error() {
    log "ERROR: $1"
    echo "SETUP Failed, refer $log for the details"
    exit 1
}


log "Entered centos/kernel/config.sh script"

log "Recieved input from previous run, KERNEL_DIR: $1, name: $2 and build_home: $3 "

cd $KERNEL_DIR
log "Current working directory: $KERNEL_DIR"

log "Cleaning the previously built kernels or the configurations"
make mrproper || handle_error "mrproper failed to clean the directory"
make distclean || handle_error "distclean failed to clean the directory"
make clean || handle_error "Failed to clean the directory"
log "Successfully cleaned the previous build data in the $KERNEL_DIR."



log "Navigated to the kernel directory"
log "Configuring the kernel..."

# Create a configuration file to build the kernel
make anolis_defconfig || handle_error "Failed to create config file"

# Change the local version to our own version
sed -i 's/^CONFIG_LOCALVERSION=.*$/CONFIG_LOCALVERSION="'$name'"/' .config
log "Changed the configured kernel local version to $name"

log "Disabling unecessary certificates in the configured kernel"
scripts/config --disable SYSTEM_TRUSTED_KEYS 
scripts/config --disable SYSTEM_REVOCATION_KEYS 
scripts/config --disable  CONFIG_DEBUG_INFO_BTF 
scripts/config --disable NET_VENDOR_NETRONOME 

log "Kernel configured successfully."
log "Going out of centos/kernel/config.sh script"
