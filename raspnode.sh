#!/bin/bash

# Fail on error , debug all lines
set -eu -o pipefail

# Some color for text
TEXT_RESET='\e[0m'
TEXT_YELLOW='\e[0;33m'
TEXT_RED_B='\e[1;31m'
TEXT_GREEN='\e[0;32m'

FOLD1='/dev/'

# Check if script has privileges
if [ "$(id -u)" -ne 0 ]; then
    echo -e $TEXT_RED_B
    echo "Please run this script with sudo" >&2
    echo -e $TEXT_RESET
    exit 1
fi

# Clean the screen
clear

function hd_conf {
    drive=$drive"1"
    umount $drive &> /dev/null
    echo -e $TEXT_YELLOW
    echo "Formatting hard disk"
    sudo mkfs.ext4 $drive -L BITCOIN
    echo -e $TEXT_GREEN
    echo "Hard disk formatted"
    PARTUUID="$(blkid -o value -s PARTUUID $drive)"
    echo  -e $TEXT_YELLOW
    echo "Creating Bitcoin data folder"
    BTCDIR=$HOME"/.bitcoin"
    mkdir $BTCDIR
    echo "Modifying fstab"
    echo "PARTUUID=$PARTUUID  $BTCDIR  ext4  defaults,noatime  0    0" >> /etc/fstab
    sudo mount -a
    echo -e $TEXT_GREEN
    echo "Hard disk configured"
    echo -e $TEXT_RESET
}

function hd_detect {
   drive_find="$(lsblk -dlnb | awk '$4>=193273528320' | numfmt --to=iec --field=4 | cut -c1-3)"
   drive=$FOLD1$drive_find
   drive_size="$(df -h $drive | sed 1d |  awk '{print $2}')"
       while true; do
           echo -e $TEXT_RED_B
           read -p "$drive_size $drive will be formatted. Are you agree? " yn
           case $yn in
               [Yy]* ) DRIVE_CONF=true;break;;
               [Nn]* ) echo "This script needs to format an entire hard disk.";echo -e $TEXT_RESET;exit;;
               * ) echo "Please answer yes or no.";;
           esac
	   echo -e $TEXT_RESET
       done
}

# Do we have an external hard drive?
while true; do
    echo -e $TEXT_YELLOW
    read -p "Is the hard drive connected? (We assume 1 Partition)" yn
    case $yn in
        [Yy]* ) hd_detect;break;; #If we have HD_CONFIG value says to configure it.
        [Nn]* ) echo "Please connect an USB hard drive an retry";exit;;
        * ) echo "Please answer yes or no.";;
    esac
    echo -e $TEXT_RESET
done

# Do we have a pendrive for SWAP?
while true; do
    echo -e $TEXT_YELLOW
    read -p "Will you use a pendrive for SWAP?" yn
    case $yn in
        [Yy]* ) SWAP_CONFIG=pen;break;; #If we have SWAP_CONFIG value says to configure it.
        [Nn]* ) echo "SWAP will be set on external Hard Disk";SWAP_CONFIG=hd;break;; #else we configure swap in the external hard drive.
        * ) echo "Please answer yes or no.";;
    esac
    echo -e $TEXT_RESET
done

echo -e $TEXT_GREEN
echo "Script will begin the installation, take a rest."
echo "____________________________________________________"
echo -e $TEXT_YELLOW
echo "Updating Raspberry"
echo -e $TEXT_RESET
sudo apt-get update
echo -e $TEXT_GREEN
echo "APT update finished..."
echo -e $TEXT_RESET
sudo apt-get -y dist-upgrade
echo -e $TEXT_GREEN
echo "APT distributive upgrade finished..."
echo -e $TEXT_RESET
sudo apt-get -y upgrade
echo -e $TEXT_GREEN
echo "APT upgrade finished..."
echo -e $TEXT_RESET
sudo apt-get -y autoremove
echo -e $TEXT_GREEN
echo "APT auto remove finished..."
echo -e $TEXT_RESET

if [ -f /var/run/reboot-required ]; then
    echo -e $TEXT_RED_B
    echo "Reboot required!"
    echo -e $TEXT_RESET
fi

echo -e $TEXT_YELLOW
echo "Installing prerequisites"
echo -e $TEXT_RESET
sudo apt-get install -y autoconf automake build-essential git libtool libgmp-dev libsqlite3-dev python python3 net-tools tmux
echo -e $TEXT_GREEN
echo "Prerequisites installed"
echo -e $TEXT_RESET

# Configure external hard drive
if [ "$DRIVE_CONF" = "true" ]; then
    echo "me voy a cargar el HD"
    #hd_conf
fi
