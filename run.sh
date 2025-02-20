#!/bin/bash

# Graphical Display
yum install python3-pip -y &> /dev/null
pip install pyfiglet &> /dev/null
pip3 install pyfiglet &> /dev/null
python3 -m pyfiglet "LKP TESTS"
# Helpers for logs
pip install pandas &> /dev/null
pip3 install pandas &> /dev/null
pip install openpyxl &> /dev/null
pip3 install openpyxl &> /dev/null
pip install netifaces &> /dev/null
pip3 install netifaces &> /dev/null
user=$(echo $USER)
if [ "$USER" != "root" ]; then
   echo "Error: Must run as root"
   exit 1
fi

build_home=$1
echo "BUILD_HOME: $build_home"
mkdir $build_home/lkp-automation-data
mkdir $build_home/lkp-automation-data/logs &> /dev/null
mkdir $build_home/lkp-automation-data/state-files &> /dev/null
mkdir $build_home/lkp-automation-data/results &> /dev/null
log=$build_home/lkp-automation-data/logs/pre-reboot-log
touch $log &> /dev/null

log () {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $log
}

handle_error() {
        log "Error: $1"
        echo "Script failed, Check out the logs in $build_home/lkp-automation-data/logs/pre-reboot-log for finding about the error"
        exit
}


# capture current working directory
loc=$(pwd)
touch $build_home/lkp-automation-data/loc &> /dev/null
echo "$loc" > $build_home/lkp-automation-data/loc
log "Captured current working directory: $loc"
# capture type of distro.
distro=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)
current_kernel=$(uname -r)
touch $build_home/lkp-automation-data/previous-kernel-name
echo "$current_kernel" > $build_home/lkp-automation-data/previous-kernel-name
log "Captured current distro: $distro, current user: $user"

log "Creating a directory for storing the built packages"
if [ ! -d "$build_home/lkp-automation-data/PACKAGES" ]; then
    mkdir -p $build_home/lkp-automation-data/PACKAGES &> /dev/null
    log "Created a new directory $build_home/lkp-automation-data/PACKAGES"
else
    log "Directory $build_home/lkp-automation-data/PACKAGES already exists, deleting the files inside the directory"
    rm -rf $build_home/lkp-automation-data/PACKAGES/* &> /dev/null
fi


echo "////////////--  STARTING WITH LKP RUNNING  --\\\\\\\\\\\\"
echo "Distro found: $distro"
echo "Current user: $user"
log "Captured distro: $distro and current user: $user"
echo " "

KERNEL_DIR="$build_home/Linux_Backport"
BRANCH=$2
BASE_COMMIT=$3
VM=$4
LKP=$5
n1=$6
n2=$7


chmod +x check_vm.sh
$loc/check_vm.sh $VM || handle_error "$VM doesn't exists" 
$loc/check_vm.sh $LKP || handle_error "$LKP doesn't exists"


git config --global --add safe.directory $KERNEL_DIR

echo $VM > $build_home/lkp-automation-data/VM
echo $LKP > $build_home/lkp-automation-data/LKP


touch $build_home/lkp-automation-data/state-files/nvms1
echo "$n1" > $build_home/lkp-automation-data/state-files/nvms1
log "the number of vms required without lkp on them: $n1"
touch $build_home/lkp-automation-data/state-files/nvms2
echo "$n2" > $build_home/lkp-automation-data/state-files/nvms2
log "the number of vms required with lkp on them: $n2"

log "Captured the vms for the 2nd and 3rd stage of the lkp running, which are $VM and $LKP" 
log "Captured the user input"

# saving the input to a tmp file
USER_INPUT="$build_home/lkp-automation-data/user-input"
rm -rf $USER_INPUT &> /dev/null
touch $USER_INPUT
echo "KERNEL_DIR:$KERNEL_DIR" >> $USER_INPUT
echo "BRANCH:$BRANCH" >> $USER_INPUT
echo "BASE_COMMIT:$BASE_COMMIT" >> $USER_INPUT
log "Find the user given input in $USER_INPUT"

# Modifying sudoers 
$loc/sudoers.sh $user $build_home || handle_error "Couldn't run sudoers modification script"
echo ""
BASE_LOCAL_VERSION="_base_kernel_$(date +%Y%m%d_%H%M%S)_"
PATCH_LOCAL_VERSION="_patches_kernel_$(date +%Y%m%d_%H%M%S)_"
log "Defined local varibles, BASE_LOCAL_VERSION=$BASE_LOCAL_VERSION and PATCH_LOCAL_VERSION=$PATCH_LOCAL_VERSION"



#create the rpm package of the patches kernel and store it to the /usr/lib/automation-logs/rpms/ for future purpose
cd $KERNEL_DIR || handle_error "Failed to navigate to $KERNEL_DIR"
log "Navigated to $KERNEL_DIR"
git switch $BRANCH || handle_error "Couldn't switch to $BRANCH, aborting...."

if command -v apt >/dev/null 2>&1; then
	echo "----------------------------"
	echo "Detected Debian based system"
	echo "----------------------------"
	echo ""
	log "Entered directory ubuntu"
	log "Creating rpm for Patch_kernel"
	$loc/ubuntu/run.sh $loc $KERNEL_DIR $PATCH_LOCAL_VERSION $build_home
	touch $build_home/lkp-automation-data/state-files/patch-kernel-version
        cp $build_home/lkp-automation-data/state-files/kernel-version $build_home/lkp-automation-data/state-files/patch-kernel-version || handle_error "couldn't copy the installed kernel version to the state_file"
        log "Successfully built the kernel patches."
        log "Intializing the steps to build the base kernel"
	cd $KERNEL_DIR || handle_error "Failed to navigate to $KERNEL_DIR"
	git switch $BRANCH || handle_error "Couldn't switch to $BRANCH, aborting...."
	git reset --hard $BASE_COMMIT || handle_error "couldn't reset head to the $BASE_COMMIT"
	$loc/ubuntu/run.sh $loc $KERNEL_DIR $BASE_LOCAL_VERSION $build_home
        touch $build_home/lkp-automation-data/state-files/base-kernel-version
        cp $build_home/lkp-automation-data/state-files/kernel-version $build_home/lkp-automation-data/state-files/base-kernel-version || handle_error "couldn't copy the installed kernel version to the state_file"
        log "Successfully built the base kernel"
	rm $build_home/lkp-automation-data/run.sh
	touch $build_home/lkp-automation-data/run.sh
	cp $loc/main/ubuntu-run.sh $build_home/lkp-automation-data/run.sh
	cd $KERNEL_DIR
	make mrproper

elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
	echo "--------------------------"
	echo "Detected RHEL based system"
	echo "--------------------------"
	echo ""
	log "Intializing the steps to build the kernel with patches"
	$loc/centos/run.sh $loc $KERNEL_DIR $PATCH_LOCAL_VERSION $build_home
	touch $build_home/lkp-automation-data/state-files/patch-kernel-version
	cp $build_home/lkp-automation-data/state-files/kernel-version $build_home/lkp-automation-data/state-files/patch-kernel-version || handle_error "couldn't copy the installed kernel version to the state_file"
	log "Successfully built the kernel patches."
	log "Intializing the steps to build the base kernel"
	cd $KERNEL_DIR || handle_error "Failed to navigate to $KERNEL_DIR"
	git switch $BRANCH || handle_error "Couldn't switch to $BRANCH, aborting...."
	git reset --hard $BASE_COMMIT || handle_error "couldn't reset head to the $BASE_COMMIT"
	$loc/centos/run.sh $loc $KERNEL_DIR $BASE_LOCAL_VERSION $build_home
	touch $build_home/lkp-automation-data/state-files/base-kernel-version
	cp $build_home/lkp-automation-data/state-files/kernel-version $build_home/lkp-automation-data/state-files/base-kernel-version || handle_error "couldn't copy the installed kernel version to the state_file"
	log "Successfully built the base kernel"
	rm $build_home/lkp-automation-data/run.sh
	touch $build_home/lkp-automation-data/run.sh
	cp $loc/main/run.sh $build_home/lkp-automation-data/run.sh
	cd $KERNEL_DIR
	make mrproper

else
	handle_error "This system is neither debian nor RHEL. System not supported"

fi
touch $build_home/lkp-automation-data/shutdown-vms.sh
cp $loc/shutdown-vms.sh $build_home/lkp-automation-data/shutdown-vms.sh
chmod +x $build_home/lkp-automation-data/shutdown-vms.sh

# saving the results excel-generator to the workspace
rm $build_home/lkp-automation-data/results/excel-generator.py
cp $loc/main/excel-generator.py $build_home/lkp-automation-data/results/excel-generator.py
chmod 777 $build_home/lkp-automation-data/results/excel-generator.py

rm $build_home/lkp-automation-data/results/add_variance.py
cp $loc/main/add_variance.py $build_home/lkp-automation-data/results/add_variance.py
chmod 777 $build_home/lkp-automation-data/results/add_variance.py

rm $build_home/lkp-automation-data/results/test_suites
cp $loc/main/test_suites $build_home/lkp-automation-data/results/test_suites
chmod 777 $build_home/lkp-automation-data/results/test_suites

# creating the service file, for running the lkp on both the kernels.


rm $build_home/lkp-automation-data/run.sh
touch $build_home/lkp-automation-data/run.sh
cp $loc/main/run.sh $build_home/lkp-automation-data/run.sh
FILE_PATH="$build_home/lkp-automation-data/run.sh"

# Defining the main-state
touch $build_home/lkp-automation-data/state-files/main-state
chmod 666 $build_home/lkp-automation-data/state-files/main-state
echo "1" > $build_home/lkp-automation-data/state-files/main-state
