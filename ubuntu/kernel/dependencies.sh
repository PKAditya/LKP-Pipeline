#!/bin/bash

# update the system
sudo apt update -y

# upgrade the system
sudo apt upgrade -y

# installing dependencies
sudo apt install ncurses-dev -y
sudo apt install dwarves -y
sudo apt install rsync -y
sudo apt install virt-install -y
