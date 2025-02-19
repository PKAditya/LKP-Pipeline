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

mkdir /var/log/lkp-automation-data &> /dev/null
mkdir /var/lib/lkp-automation-data &> /dev/null
mkdir /var/lib/lkp-automation-data/state-files &> /dev/null
mkdir /var/lib/lkp-automation-data/results &> /dev/null
log=/var/log/lkp-automation-data/pre-reboot-log
touch $log &> /dev/null

log () {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $log
}

handle_error() {
        log "Error: $1"
        echo "Script failed, Check out the logs in /var/log/lkp-automation-data/pre-reboot-log for finding about the error"
        exit
}


# capture current working directory
loc=$(pwd)
touch /var/lib/lkp-automation-data/loc &> /dev/null
echo "$loc" > /var/lib/lkp-automation-data/loc
log "Captured current working directory: $loc"
# capture type of distro.
distro=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)
current_kernel=$(uname -r)
touch /var/lib/lkp-automation-data/previous-kernel-name
echo "$current_kernel" > /var/lib/lkp-automation-data/previous-kernel-name
log "Captured current distro: $distro, current user: $user"

log "Creating a directory for storing the built packages"
if [ ! -d "/var/lib/lkp-automation-data/PACKAGES" ]; then
    mkdir -p /var/lib/lkp-automation-data/PACKAGES &> /dev/null
    log "Created a new directory /var/lib/lkp-automation-data/PACKAGES"
else
    log "Directory /var/lib/lkp-automation-data/PACKAGES already exists, deleting the files inside the directory"
    rm -rf /var/lib/lkp-automation-data/PACKAGES/* &> /dev/null
fi


echo "////////////--  STARTING WITH LKP RUNNING  --\\\\\\\\\\\\"
echo "Distro found: $distro"
echo "Current user: $user"
log "Captured distro: $distro and current user: $user"
echo " "

# user input
read -p "Enter kernel repository path: " KERNEL_DIR
read -p "Enter the branch name with out including the remote repository: " BRANCH
read -p "Enter the commit sha id of the base_kernel: " BASE_COMMIT
read -p "Enter the vm name without lkp on it: " VM
read -p "Enter the vm name with lkp on it: " LKP
read -p "Enter the number of vms required without lkp on them: " n1
read -p "Enter the number of vms required with lkp on them: " n2
chmod +x check_vm.sh
$loc/check_vm.sh $VM || handle_error "$VM doesn't exists" 
$loc/check_vm.sh $LKP || handle_error "$LKP doesn't exists"


git config --global --add safe.directory $KERNEL_DIR

echo $VM > /var/lib/lkp-automation-data/VM
echo $LKP > /var/lib/lkp-automation-data/LKP


touch /var/lib/lkp-automation-data/state-files/nvms1
echo "$n1" > /var/lib/lkp-automation-data/state-files/nvms1
log "the number of vms required without lkp on them: $n1"
touch /var/lib/lkp-automation-data/state-files/nvms2
echo "$n2" > /var/lib/lkp-automation-data/state-files/nvms2
log "the number of vms required with lkp on them: $n2"

log "Captured the vms for the 2nd and 3rd stage of the lkp running, which are $VM and $LKP" 
log "Captured the user input"

# saving the input to a tmp file
USER_INPUT=/var/lib/lkp-automation-data/user-input
rm -rf $USER_INPUT &> /dev/null
touch $USER_INPUT
echo "KERNEL_DIR:$KERNEL_DIR" >> $USER_INPUT
echo "BRANCH:$BRANCH" >> $USER_INPUT
echo "BASE_COMMIT:$BASE_COMMIT" >> $USER_INPUT
log "Find the user given input in $USER_INPUT"

# Modifying sudoers 
$loc/sudoers.sh $user || handle_error "Couldn't run sudoers modification script"
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
	$loc/ubuntu/run.sh $loc $KERNEL_DIR $PATCH_LOCAL_VERSION
	touch /var/lib/lkp-automation-data/state-files/patch-kernel-version
        cp /var/lib/lkp-automation-data/state-files/kernel-version /var/lib/lkp-automation-data/state-files/patch-kernel-version || handle_error "couldn't copy the installed kernel version to the state_file"
        log "Successfully built the kernel patches."
        log "Intializing the steps to build the base kernel"
	cd $KERNEL_DIR || handle_error "Failed to navigate to $KERNEL_DIR"
	git switch $BRANCH || handle_error "Couldn't switch to $BRANCH, aborting...."
	git reset --hard $BASE_COMMIT || handle_error "couldn't reset head to the $BASE_COMMIT"
	$loc/ubuntu/run.sh $loc $KERNEL_DIR $BASE_LOCAL_VERSION
        touch /var/lib/lkp-automation-data/state-files/base-kernel-version
        cp /var/lib/lkp-automation-data/state-files/kernel-version /var/lib/lkp-automation-data/state-files/base-kernel-version || handle_error "couldn't copy the installed kernel version to the state_file"
        log "Successfully built the base kernel"
	rm /var/lib/lkp-automation-data/run.sh
	touch /var/lib/lkp-automation-data/run.sh
	cp $loc/main/ubuntu-run.sh /var/lib/lkp-automation-data/run.sh

elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
	echo "--------------------------"
	echo "Detected RHEL based system"
	echo "--------------------------"
	echo ""
	log "Intializing the steps to build the kernel with patches"
	$loc/centos/run.sh $loc $KERNEL_DIR $PATCH_LOCAL_VERSION
	touch /var/lib/lkp-automation-data/state-files/patch-kernel-version
	cp /var/lib/lkp-automation-data/state-files/kernel-version /var/lib/lkp-automation-data/state-files/patch-kernel-version || handle_error "couldn't copy the installed kernel version to the state_file"
	log "Successfully built the kernel patches."
	log "Intializing the steps to build the base kernel"
	cd $KERNEL_DIR || handle_error "Failed to navigate to $KERNEL_DIR"
	git switch $BRANCH || handle_error "Couldn't switch to $BRANCH, aborting...."
	git reset --hard $BASE_COMMIT || handle_error "couldn't reset head to the $BASE_COMMIT"
	$loc/centos/run.sh $loc $KERNEL_DIR $BASE_LOCAL_VERSION
	touch /var/lib/lkp-automation-data/state-files/base-kernel-version
	cp /var/lib/lkp-automation-data/state-files/kernel-version /var/lib/lkp-automation-data/state-files/base-kernel-version || handle_error "couldn't copy the installed kernel version to the state_file"
	log "Successfully built the base kernel"
	rm /var/lib/lkp-automation-data/run.sh
	touch /var/lib/lkp-automation-data/run.sh
	cp $loc/main/run.sh /var/lib/lkp-automation-data/run.sh

else
	handle_error "This system is neither debian nor RHEL. System not supported"

fi
touch /var/lib/lkp-automation-data/shutdown-vms.sh
cp $loc/shutdown-vms.sh /var/lib/lkp-automation-data/shutdown-vms.sh
chmod +x /var/lib/lkp-automation-data/shutdown-vms.sh

# saving the results excel-generator to the workspace
rm /var/lib/lkp-automation-data/results/excel-generator.py
cp $loc/main/excel-generator.py /var/lib/lkp-automation-data/results/excel-generator.py
chmod 777 /var/lib/lkp-automation-data/results/excel-generator.py

rm /var/lib/lkp-automation-data/results/add_variance.py
cp $loc/main/add_variance.py /var/lib/lkp-automation-data/results/add_variance.py
chmod 777 /var/lib/lkp-automation-data/results/add_variance.py


# creating the service file, for running the lkp on both the kernels.


rm /var/lib/lkp-automation-data/run.sh
touch /var/lib/lkp-automation-data/run.sh
cp $loc/main/run.sh /var/lib/lkp-automation-data/run.sh
FILE_PATH="/var/lib/lkp-automation-data/run.sh"


cp $loc/main/test_suites  /var/lib/lkp-automation-data/results/test_suites


# Defining the main-state
touch /var/lib/lkp-automation-data/state-files/main-state
chmod 666 /var/lib/lkp-automation-data/state-files/main-state
echo "1" > /var/lib/lkp-automation-data/state-files/main-state


# Set the name of the service
SERVICE_NAME="lkp.service"
cp $loc/main/lkp.service /etc/systemd/system/lkp.service

wlkp=$(which lkp)
rlkp="/usr/local/bin/lkp"
whack=$(which hackbench)
rhack="/usr/local/bin/hackbench"

cd $loc
cd ../
git clone https://github.com/PKumarAditya/LKP_Automated.git

if [[ -x "$rlkp" && -x "$rhack" ]]; then
	log "lkp and hackbench are already present in the system, moving to the next step"
	log "creating lkp files for running lkp"
        cd $loc
        cd ../
        cd LKP_Automated
        make
        systemctl stop lkprun.service
        if [[ ! -x "$rlkp" || ! -x "$rhack" ]]; then
                echo "Either the lkp or hackbench didnot install properly"
                handle_error "Couldn't install lkp or hackbench, install them manually and run the lkp.service file"
        fi

else
	log "Couldn't find lkp and hackbench in the system, installing lkp and hackbench"
	cd $loc
	cd ../
	cd LKP_Automated
	make
	systemctl stop lkprun.service
	if [[ ! -x "$rlkp" || ! -x "$rhack" ]]; then
		echo "Either the lkp or hackbench didnot install properly"
		handle_error "Couldn't install lkp or hackbench, install them manually and run the lkp.service file"
	fi
fi

chmod 777 /var/lib/lkp-automation-data/run.sh
chmod 777 /etc/systemd/system/lkp.service
# Reload systemd and start the service
systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
systemctl start ${SERVICE_NAME}

echo "Service ${SERVICE_NAME} has been created and started."
