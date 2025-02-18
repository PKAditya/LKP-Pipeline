#!/bin/bash

loc=$1
KERNEL_DIR=$2
LOCAL_VERSION=$3
build_home=$4
if [ ! -d $build_home/lkp-automation-data/state-files ]; then
	mkdir $build_home/lkp-automation-data/state-files &> /dev/null
fi
touch $build_home/lkp-automation-data/state-files/kernel_name &> /dev/null


# log handling
log="$build_home/lkp-automation-data/logs/pre-reboot-log"

log() {
	echo "$1" >> log
}
handle_error() {
	echo "ERROR: $1" >> log
	exit 1
}
log "Entered $loc/centos directory"
cd $KERNEL_DIR || handle_error "Couldnt switch to $KERNEL_DIR"
log "Current working directory: $KERNEL_DIR"
# running kernel build help script
$loc/centos/kernel/run.sh $loc $KERNEL_DIR $LOCAL_VERSION $build_home || handle_error "Failed to run kernel build steps"
log "Going out of centos directory"
