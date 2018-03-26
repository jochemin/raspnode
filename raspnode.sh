#!/bin/bash
##############################################################################################
#
# jochemin
#
#Bitcoin + Lightning node installation bash script
#
#Raspberry + external USB drive required, pendrive recommended
#
#BTC Donations. Thank you!! --> 3FM6FypcrSVhdHh7cpVQMrhPXPZ6zcXeYU
#
#LN 1000 satoshi --> lnbc10u1pdtyqucpp52fu993pgr4vx8kw7un53wc6nr2v979ca53wsr7swkaxaxewgep6qdqlgysxyet9wgsxvmmjyp4x7cmgv4kkjmscqzysxq92ptxs5jyam5u65rlfhrls2khe60lt93m2zyv06tzjkxt9u6l50jy63v7xu4pqah2kr3kljmhq8zyeaw02t3vcygde4nglm48fruk6x4lmf8gqueegmf
#
#Connect to my LN node --> 02d249db09237f974f1c67775accee37a9d1eb3f04f236dda177f5a5c083094f15@jocheminlnd1.ddns.net:9735
##############################################################################################

# Fail on error , debug all lines#############################################################
set -eu -o pipefail
##############################################################################################

#Some color for text#########################################################################
TEXT_RESET='\e[0m'
TEXT_YELLOW='\e[0;33m'
TEXT_RED_B='\e[1;31m'
#TEXT_GREEN='\e[0;32m'
##############################################################################################

# variables###################################################################################
user=$(logname)
userhome='/home/'$user
FOLD1='/dev/'
PUBLICIP="$(curl ipinfo.io/ip)"
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
    drive_size="$(df -h "$drive" | sed 1d |  awk '{print $2}')"
    while true; do
        echo -e "$TEXT_RED_B"
        read -p "$drive_size $drive will be formatted. Do you agree? (y/n) " yn
        case $yn in
            [Yy]* ) DRIVE_CONF=true;break;;
            [Nn]* ) echo "This script needs to format an entire hard disk.";echo -e "$TEXT_RESET";exit;;
            * ) echo "Please answer yes or no. (y/n)";;
        esac
        echo -e "$TEXT_RESET"
    done
}
##############################################################################################


# HD configuration############################################################################
function hd_conf {
    drive=$drive"1"
    if mount | grep "$drive" > /dev/null;then
        umount -l "$drive" > /dev/null
    fi
    writeyellow 'Formatting hard disk'
    sudo mkfs.ext4 -F "$drive" -L BITCOIN
    writegreen 'Hard disk formatted'
    UUID="$(blkid -o value -s UUID "$drive")"
    writeyellow 'Creating Bitcoin data folder'
    BTCDIR='/home/'$user'/.bitcoin'
    mkdir -p "$BTCDIR"
    writeyellow 'Modifying fstab'
    sudo sed -i".bak" "/$UUID/d" /etc/fstab
    echo "UUID=$UUID  $BTCDIR  ext4  defaults,noatime  0    0" >> /etc/fstab
    if mount | grep "$drive" > /dev/null;then
        :
    else
        sudo mount -a
    fi
    sudo chmod 777 "$BTCDIR"
    writegreen 'Hard disk configured'
}
##############################################################################################

# CONFIGURE SWAP IN THE HARD DRIVE############################################################
function swap_conf {
    writeyellow 'Configuring swap in the hard drive'
    sudo -u "$user" mkdir -p /home/"$user"/.bitcoin/swap
    dd if=/dev/zero of=/home/"$user"/.bitcoin/swap/swap.file bs=1M count=2148
    chmod 600 /home/"$user"/.bitcoin/swap/swap.file
    sudo sed -i".bak" "/CONF_SWAPFILE/d" /etc/dphys-swapfile
    sudo sed -i".bak" "/CONF_SWAPSIZE/d" /etc/dphys-swapfile
    echo "CONF_SWAPFILE=/home/$user/.bitcoin/swap/swap.file" >> /etc/dphys-swapfile
    echo "CONF_SWAPSIZE=2048" >> /etc/dphys-swapfile
    mkswap /home/"$user"/.bitcoin/swap/swap.file
    swapon /home/"$user"/.bitcoin/swap/swap.file
    echo "/home/$user/.bitcoin/swap/swap.file  none  swap  defaults  0    0" >> /etc/fstab
    writegreen 'swap configured'
}
# USER INPUT##################################################################################
function user_input {
    # Do we have an external hard drive?
    while true; do
        echo -e "$TEXT_YELLOW"
        read -p "Is the hard drive connected? It will be formated. (y/n)" yn
        case $yn in
            [Yy]* ) hd_detect;break;; #If we have HD_CONFIG value says to configure it.
            [Nn]* ) echo "Please connect an USB hard drive an retry";exit;;
            * ) echo "Please answer yes or no. (y/n)";;
        esac
    done
    echo 'Bitcoin and LND need a RPC user and password, please insert data.'
    read -p 'Insert username: ' rpcuser
    read -s -p 'Insert password: (will not be shown) ' rpcpass
    echo 
    read -p 'Insert your LND node alias: ' LNALIAS
    echo -e "$TEXT_RESET"
    # Do we have a pendrive for SWAP? IMPROVEMENT?
    #while true; do
    #    echo -e $TEXT_YELLOW
    #    read -p "Will you use a pendrive for SWAP?" yn
    #    case $yn in
    #        [Yy]* ) SWAP_CONFIG=pen;break;; #If we have SWAP_CONFIG value says to configure it.
    #        [Nn]* ) echo "SWAP will be set on external Hard Disk";SWAP_CONFIG=hd;break;; #else we configure swap in the external hard drive.
    #        * ) echo "Please answer yes or no.";;
    #    esac
    #    echo -e $TEXT_RESET
    #done
}
##############################################################################################

# NETWORK ADDRESS ############################################################################
function Network {
    network_address=$(ip -o -f inet addr show | awk '/scope global/{sub(/[^.]+\//,"0/",$4);print $4}')
}
##############################################################################################

# SECURE RASPBERRY ###########################################################################
function secure {
    Network
    writeyellow 'Configuring iptables'
    iptables -A INPUT -s "$network_address" -j ACCEPT
    writegreen 'All trafic from LAN allowed'
    iptables -A INPUT -p tcp --syn -m connlimit --connlimit-above 250 --connlimit-mask 0 -j DROP
    writegreen 'Limited total incoming connections to 250'
    iptables -A INPUT -p tcp --syn --dport 22 -m connlimit --connlimit-above 2 --connlimit-mask 0 -j DROP
    writegreen 'Limited SSH connections to port 22 to 2'
    iptables -A INPUT -p tcp --syn --dport 8333 -m connlimit --connlimit-above 120 --connlimit-mask 0 -j DROP
    writegreen 'Limited total connections to port 8333 (Bitcoin Mainnet) to 120'
    iptables -A INPUT -p tcp --syn --dport 9735 -m connlimit --connlimit-above 120 --connlimit-mask 0 -j DROP
    writegreen 'Limited total connections to port 9735 (Lightning Network) to 120'
    iptables -I INPUT -p tcp --syn --dport 8333 -m connlimit --connlimit-above 6 -j REJECT
    writegreen 'Limited to 6 connections from one IP to port 8333'
    iptables -I INPUT -p tcp --syn --dport 9735 -m connlimit --connlimit-above 6 -j REJECT
    writegreen 'Limited to 6 connections from one IP to port 9735'
    iptables-save > /etc/iptables.conf
    sed -i".bak" '/exit/d' /etc/rc.local
    echo 'iptables-restore < /etc/iptables.conf' >> /etc/rc.local
    echo 'exit 0' >> /etc/rc.local
    writegreen 'Rules saved'
}

# UPDATE RASPBERRY ###########################################################################
function update_rasp {
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
}
##############################################################################################

# INSTALL BERKELEY (4.8.30)###################################################################
function install_berkeley {
    writeyellow 'Installing database...'
    sudo -u "$user" mkdir -p "$userhome"/bin
    cd "$userhome"/bin
    sudo -u "$user" wget http://download.oracle.com/berkeley-db/db-4.8.30.NC.tar.gz
    sudo -u "$user" tar -xzvf db-4.8.30.NC.tar.gz
    cd db-4.8.30.NC/build_unix/
    ../dist/configure --enable-cxx
    make
    sudo make install
    writegreen 'Database installed'
}
##############################################################################################

# INSTALL BITCOIN CORE #######################################################################
function install_bitcoin_core {
    writeyellow 'Installing Bitcoin Core'
    rm -fR "$userhome"/bin/bitcoin
    cd "$userhome"/bin
    git clone -b 0.16 https://github.com/bitcoin/bitcoin.git
    cd bitcoin/
    ./autogen.sh
    ./configure CPPFLAGS="-I/usr/local/BerkeleyDB.4.8/include -O2" LDFLAGS="-L/usr/local/BerkeleyDB.4.8/lib" --enable-upnp-default
    make
    sudo make install
    writegreen 'Bitcoin Core Installed'
}
##############################################################################################

# BUILD BITCOIN.CONF##########################################################################
function build_bitcoinconf {
    echo 'zmqpubrawblock=tcp://127.0.0.1:18501' > /home/"$user"/.bitcoin/bitcoin.conf
    echo 'zmqpubrawtx=tcp://127.0.0.1:18501' >> /home/"$user"/.bitcoin/bitcoin.conf
    echo "rpcuser=$rpcuser" >> /home/"$user"/.bitcoin/bitcoin.conf
    echo "rpcpassword=$rpcpass" >> /home/"$user"/.bitcoin/bitcoin.conf
    echo 'dbcache=100' >> /home/"$user"/.bitcoin/bitcoin.conf
    echo 'maxmempool=100' >> /home/"$user"/.bitcoin/bitcoin.conf
    echo 'usehd=1' >> /home/"$user"/.bitcoin/bitcoin.conf
    echo 'txindex=1' >> /home/"$user"/.bitcoin/bitcoin.conf
    echo 'daemon=1' >> /home/"$user"/.bitcoin/bitcoin.conf
    echo 'server=1' >> /home/"$user"/.bitcoin/bitcoin.conf
}
##############################################################################################

# INSTALL LND#################################################################################
function install_lnd {
    writeyellow 'Installing LND 0.4 BETA'
    cd "$userhome"
    sudo -u "$user" mkdir -p download
    cd download
    wget https://github.com/lightningnetwork/lnd/releases/download/v0.4-beta/lnd-linux-arm-v0.4-beta.tar.gz
    tar -xzf lnd-linux-arm-v0.4-beta.tar.gz
    sudo install -m 0755 -o root -g root -t /usr/local/bin lnd-linux-arm-v0.4-beta/*
}
##############################################################################################

# BUILD LND CONFIG FILE#######################################################################
function build_lndconf {
    sudo -u "$user" mkdir -p "$userhome"/.lnd
    echo 'bitcoin.active=1' > "$userhome"/.lnd/lnd.conf
    echo "externalip=$PUBLICIP" >> "$userhome"/.lnd/lnd.conf
    echo "alias=$LNALIAS" >> "$userhome"/.lnd/lnd.conf
    echo 'color=#1d8c09' >> "$userhome"/.lnd/lnd.conf
    echo 'bitcoin.node=bitcoind' >> "$userhome"/.lnd/lnd.conf
    echo "bitcoind.rpcuser=$rpcuser" >> "$userhome"/.lnd/lnd.conf
    echo "bitcoind.rpcpass=$rpcpass" >> "$userhome"/.lnd/lnd.conf
    echo 'bitcoind.zmqpath=tcp://127.0.0.1:18501' >> "$userhome"/.lnd/lnd.conf
    #autopilot.active=1 >> $userhome/.lnd/lnd.conf
    #autopilot.maxchannels=5 >> $userhome/.lnd/lnd.conf
    #autopilot.allocation=0.6 >> $userhome/.lnd/lnd.conf
}
##############################################################################################

# INSTALL PREREQUISITES#######################################################################
function install_prerequisites {
    writeyellow 'Installing prerequisites'
    sudo apt-get install -y autoconf automake build-essential git libtool libevent-dev libgmp-dev libsqlite3-dev python python3 net-tools libboost-system-dev libboost-filesystem-dev libboost-chrono-dev libboost-program-options-dev libboost-test-dev libboost-thread-dev libssl-dev libzmq3-dev tmux
    writegreen 'Prerequisites installed'
}
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

# Check parameters ###########################################################################
if [ $1 = "secure" ];then
    secure;exit 1
fi
##############################################################################################

# User input##################################################################################
user_input
##############################################################################################

# Prerequisites###############################################################################
writegreen 'Script will begin the installation, take a rest.'
writegreen '____________________________________________________'
update_rasp
install_prerequisites
secure
##############################################################################################

# Configure external hard drive###############################################################
if [ "$DRIVE_CONF" = "true" ]; then
    hd_conf
    swap_conf
fi
##############################################################################################

# INSTALL DATABASE (BERKELEY 4.8.30)##########################################################
install_berkeley
##############################################################################################

# INSTALL BITCOIN CORE #######################################################################
install_bitcoin_core
build_bitcoinconf
##############################################################################################

#INSTALL LND##################################################################################
install_lnd
build_lndconf
##############################################################################################

# START BITCOIND##############################################################################
writeyellow 'Starting Bitcoin Core'
sudo -u "$user" bitcoind &
writegreen 'Bitcoin Core started'
##############################################################################################

# START LND ##################################################################################
# Wait 20 minutes for bitcoind to warm up
writeyellow 'Waiting 20 minutes to start LND'
sleep 20m
sudo -u "$user" tmux new-session -d -s LND
sudo -u "$user" tmux send-keys -t LND "lnd --bitcoin.mainnet" Enter
writegreen 'LND started in tmux session'
##############################################################################################

#THE END #####################################################################################
writegreen 'Please create a new Lightning wallet with lncli create.'
writegreen 'To enter LND tmux session --> tmux a LND'
writegreen 'Now you have to wait until syncing. Patience.'
# MAIN - MAIN - MAIN - MAIN - MAIN - MAIN - MAIN - MAIN - MAIN - MAIN - MAIN - MAIN - MAIN ###
