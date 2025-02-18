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
	echo "Refer $log to check the details of the error"
	exit 1
}

log "Entered directory $loc/ubuntu/kernel"
log "Installing dependencies required for the kernel build"

$loc/ubuntu/kernel/dependencies.sh || handle_error "Failed to run $loc/ubuntu/kernel/dependencies.sh"
log "Successfully installed kernel build essential dependencies"

if [[ -d $KERNEL_DIR ]]; then
	cd "$KERNEL_DIR"
        log "Directory $KERNEL_DIR exists"
	log "Running the configuration script: $loc/ubuntu/kernel/config.sh"
        $loc/ubuntu/kernel/config.sh $KERNEL_DIR $LOCAL_VERSION $build_home || handle_error "Failed running $loc/ubuntu/kernel/config.sh"
	log "Successfully ran the configuration"

	log "Proceeding with building the kernel configured with the local version"
	$loc/ubuntu/kernel/install.sh $LOCAL_VERSION $build_home || handle_error "Cannot build the configured kernel."
else
        handle_error "Failed to change to kernel directory, Directory $KERNEL_DIR doesn't exists"
fi

