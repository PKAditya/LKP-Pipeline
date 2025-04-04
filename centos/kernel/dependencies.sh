#!/bin/bash


# update the system
echo "updating the system."
sudo yum update -y &> /dev/null

echo "Upgrading the system."
# upgrade the system
sudo yum upgrade -y &> /dev/null

# installing dependencies
echo "Installing dwarves"
sudo yum install dwarves -y &> /dev/null
echo "Installing rsync"
sudo yum install rsync -y &> /dev/null
echo "Installing elfutils-libelf-devel"
sudo dnf install elfutils-libelf-devel -y &> /dev/null
echo "Installing multiple dependencies required for kernel build"
sudo yum install gcc gcc-c++ kernel-devel perl make numactl openssl openssl-devel libmpc mpfr libstdc++-devel libtool bison flex zlib zlib-devel ncurses-devel -y &> /dev/null

sudo yum install createrepo rpm-build rpmdevtools -y &> /dev/null
sudo yum install virt-clone -y &> /dev/null
