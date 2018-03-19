#!/bin/bash
##############################################################################################
#                                                                                            #
# jochemin                                                                                   #
#                                                                                            #
#Bitcoin + Lightning node installation bash script                                           #
#                                                                                            #
#Raspberry + external USB drive required, pendrive recommended                               #
#                                                                                            #
#BTC Donations. Thank you!! --> 3FM6FypcrSVhdHh7cpVQMrhPXPZ6zcXeYU                           #
##############################################################################################

# Fail on error , debug all lines#############################################################
set -eu -o pipefail
##############################################################################################

# Some color for text#########################################################################
TEXT_RESET='\e[0m'
TEXT_YELLOW='\e[0;33m'
TEXT_RED_B='\e[1;31m'
TEXT_GREEN='\e[0;32m'
##############################################################################################

# variables###################################################################################
user=$(logname)
userhome='/home/'$user
FOLD1='/dev/'
##############################################################################################

# Color functions#############################################################################
function writegreen(){
    echo -e -n "'\e[0;32m$1"
    echo -e -n '\033[0m\n'
}
function writeyellow(){
    echo -e -n "'\e[0;33m$1"
    echo -e -n '\033[0m\n'
}
function writered(){
    echo -e -n "'\e[1;31m$1"
    echo -e -n '\033[0m\n'
}
##############################################################################################

# External HD detection and prompt for format#################################################
function hd_detect {
    drive_find="$(lsblk -dlnb | awk '$4>=193273528320' | numfmt --to=iec --field=4 | cut -c1-3)"
    drive=$FOLD1$drive_find
    drive_size="$(df -h $drive | sed 1d |  awk '{print $2}')"
    while true; do
        echo -e $TEXT_RED_B
        read -p "$drive_size $drive will be formatted. Are you agree? (y/n) " yn
        case $yn in
            [Yy]* ) DRIVE_CONF=true;break;;
            [Nn]* ) echo "This script needs to format an entire hard disk.";echo -e $TEXT_RESET;exit;;
            * ) echo "Please answer yes or no. (y/n)";;
        esac
        echo -e $TEXT_RESET
    done
}
##############################################################################################


# HD configuration############################################################################
function hd_conf {
    drive=$drive"1"
    if mount | grep $drive > /dev/null;then
        echo 'lo detecto montado'
        umount $drive > /dev/null
    fi
    writeyellow 'Formatting hard disk'
    sudo mkfs.ext4 -F $drive -L BITCOIN
    writegreen 'Hard disk formatted'
    PARTUUID="$(blkid -o value -s PARTUUID $drive)"
    writeyellow 'Creating Bitcoin data folder'
    BTCDIR='/home/'$user'/.bitcoin'
    mkdir -p $BTCDIR
    writeyellow 'Modifying fstab'
    sudo sed -i".bak" "/$PARTUUID/d" /etc/fstab
    echo "PARTUUID=$PARTUUID  $BTCDIR  ext4  defaults,noatime  0    0" >> /etc/fstab
    if mount | grep $drive > /dev/null;then
        :
    else
        sudo mount -a
    fi
    writegreen 'Hard disk configured'
}
##############################################################################################
# MAIN - MAIN - MAIN - MAIN - MAIN - MAIN - MAIN - MAIN - MAIN - MAIN - MAIN - MAIN - MAIN ###
# Check if script is launched with sudo#######################################################
if [ "$(id -u)" -ne 0 ]; then
    writered "Please run this script with sudo" >&2
    exit 1
fi
##############################################################################################

# Clean the screen############################################################################
clear
##############################################################################################

# User input##################################################################################
# Do we have an external hard drive?
while true; do
    echo -e $TEXT_YELLOW
    read -p "Is the hard drive connected? It will be formated. (y/n)" yn
    case $yn in
        [Yy]* ) hd_detect;break;; #If we have HD_CONFIG value says to configure it.
        [Nn]* ) echo "Please connect an USB hard drive an retry";exit;;
        * ) echo "Please answer yes or no. (y/n)";;
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
##############################################################################################

# Prerequisites###############################################################################
writegreen 'Script will begin the installation, take a rest.'
writegreen '____________________________________________________'
writeyellow 'Updating Raspberry'
sudo apt-get update
writegreen 'APT update finished...'
sudo apt-get -y dist-upgrade
writegreen 'APT distributive upgrade finished...'
sudo apt-get -y upgrade
writegreen 'APT upgrade finished...'
sudo apt-get -y autoremove
writegreen 'APT auto remove finished...'

if [ -f /var/run/reboot-required ]; then
    writered 'Reboot required!'
fi

writeyellow 'Installing prerequisites'
sudo apt-get install -y autoconf automake build-essential git libtool libgmp-dev libsqlite3-dev python python3 net-tools tmux
writegreen 'Prerequisites installed'
##############################################################################################

# Configure external hard drive###############################################################
if [ "$DRIVE_CONF" = "true" ]; then
    hd_conf
fi
##############################################################################################

# Install Berkeley-db 4.8.30##################################################################
writeyellow 'Installing database...'
sudo -u $user mkdir -p $userhome/bin
cd $userhome/bin
sudo -u $user wget http://download.oracle.com/berkeley-db/db-4.8.30.NC.tar.gz
sudo -u $user tar -xzvf db-4.8.30.NC.tar.gz
cd db-4.8.30.NC/build_unix/
../dist/configure --enable-cxx
make
sudo make install
writegreen 'Database installed'
##############################################################################################

# Install Bitcoin Core########################################################################
writeyellow 'Installing Bitcoin Core'
rm -R $userhome/bin/bitcoin
cd $userhome/bin
git clone https://github.com/bitcoin/bitcoin.git
cd bitcoin/
./autogen.sh
./configure CPPFLAGS="-I/usr/local/BerkeleyDB.4.8/include -O2" LDFLAGS="-L/usr/local/BerkeleyDB.4.8/lib" --enable-upnp-default
make
sudo make install
writegreen 'Bitcoin Core Installed'
##############################################################################################
# MAIN - MAIN - MAIN - MAIN - MAIN - MAIN - MAIN - MAIN - MAIN - MAIN - MAIN - MAIN - MAIN ###
