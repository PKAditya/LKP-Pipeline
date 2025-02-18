#!/bin/bash

loc=$1
KERNEL_DIR=$2
LOCAL_VERSION=$3
build_home=$4

log="$build_home/lkp-automation-data/logs/pre-reboot-log"

# function defined to log the every step
log() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $log
}

# function defined to handle error
handle_error() {
	log "ERROR: $1" >> $log
	echo "$1"
	exit 1
}

log "Entered directory $loc/centos/kernel"
log "Installing dependencies required for the kernel build"
$loc/centos/kernel/dependencies.sh || handle_error "Failed to run $loc/centos/kernel/dependencies.sh"
log "Successfully installed kernel build essential dependencies"

if [[ -d $KERNEL_DIR ]]; then
	cd "$KERNEL_DIR" || handle_error "Couldn't switch to $KERNEL_DIR, give proper input"
        $loc/centos/kernel/config.sh $KERNEL_DIR $LOCAL_VERSION $build_home || handle_error "Failed running $loc/centos/kernel/config.sh"

	$loc/centos/kernel/install.sh $LOCAL_VERSION $build_home|| handle_error "Cannot build the configured kernel."
else
        handle_error "Failed to change to kernel directory, Directory $KERNEL_DIR doesn't exists"
fi


log "Going out of $loc/centos/kernel/run.sh script"
