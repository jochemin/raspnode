#!/bin/bash

    set -eu -o pipefail # fail on error , debug all lines

    TEXT_RESET='\e[0m'
    TEXT_YELLOW='\e[0;33m'
    TEXT_RED_B='\e[1;31m'
    FOLD1='/dev/'

    sudo -n true
    test $? -eq 0 || exit 1 "you should have sudo priveledge to run this script"

    clear

    function hd_conf {
       drive=$drive"1"
       #umount $drive &> /dev/null
       #sudo mkfs.ext4 $drive -L BITCOIN
       PARTUUID="$(blkid -o value -s PARTUUID $drive)"
       BTCDIR=$HOME"/.bitcoin"
       #mkdir $BTCDIR
       echo "PARTUUID=$PARTUUID  $BTCDIR  ext4  defaults,noatime  0    0" >> /etc/fstab
       sudo mount -a
    }

    function hd_detect {
       drive_find="$(lsblk -dlnb | awk '$4>=193273528320' | numfmt --to=iec --field=4 | cut -c1-3)"
       drive=$FOLD1$drive_find
       drive_size="$(df -h $drive | sed 1d |  awk '{print $2}')"
           while true; do
               read -p "$drive_size $drive will be formatted. Are you agree? " yn
               case $yn in
                   [Yy]* ) hd_conf;break;;
                   [Nn]* ) echo "This script needs to format an entire hard disk.";exit;;
                   * ) echo "Please answer yes or no.";;
               esac
           done
    }

    while true; do
        read -p "Is the hard drive connected? (We assume 1 Partition)" yn
        case $yn in
            [Yy]* ) HD_CONFIG=1;break;;
            [Nn]* ) echo "Please connect an USB hard drive an retry";exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    
     while true; do
        read -p "Will you use a pendrive for SWAP?" yn
        case $yn in
            [Yy]* ) SWAP_CONFIG=1;break;;
            [Nn]* ) echo "SWAP will be set on external Hard Disk";SWAP_CONFIG=0;exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done

    echo -e $TEXT_YELLOW
    echo "Script will begin the installation, take a rest."

    echo updating Raspberry
    sudo apt-get update
    echo -e $TEXT_YELLOW
    echo 'APT update finished...'
    echo -e $TEXT_RESET
    sudo apt-get -y dist-upgrade
    echo -e $TEXT_YELLOW
    echo 'APT distributive upgrade finished...'
    echo -e $TEXT_RESET
    sudo apt-get -y upgrade
    echo -e $TEXT_YELLOW
    echo 'APT upgrade finished...'
    echo -e $TEXT_RESET
    sudo apt-get -y autoremove
    echo -e $TEXT_YELLOW
    echo 'APT auto remove finished...'
    echo -e $TEXT_RESET

    if [ -f /var/run/reboot-required ]; then
        echo -e $TEXT_RED_B
        echo 'Reboot required!'
        echo -e $TEXT_RESET
    fi

    echo installing pre-requisites
    sudo apt-get install -y autoconf automake build-essential git libtool libgmp-dev libsqlite3-dev python python3 net-tools tmux

    if ["$HD_CONFIG" -eq "1"]; then
       hd_detect
    fi

    if [
