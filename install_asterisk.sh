#!/bin/sh
# Install Vanilla Asterisk 20.6 on Ubuntu 22.04

#--------------------------------------------------
# Update Server
#--------------------------------------------------
sudo apt update && sudo apt -y upgrade 
sudo apt autoremove -y

# need to find odbc-mariadb replacement
apt-get install -y linux-headers-`uname -r` 

#--------------------------------------------------
# Set up the timezones
#--------------------------------------------------
# set the correct timezone on ubuntu
timedatectl set-timezone Africa/Kigali
timedatectl

#----------------------------------------------------
# Disable password authentication
#----------------------------------------------------
sudo sed -i 's/#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config 
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo service sshd restart

sudo apt install -y bison flex sox mpg123 sqlite3 pkg-config automake libtool autoconf unixodbc-dev uuid libasound2-dev libcurl4-openssl-dev ffmpeg \
libogg-dev libvorbis-dev libicu-dev libical-dev libneon27-dev libsrtp2-dev libspandsp-dev libtool-bin unixodbc cron ipset htop sngrep gnupg2 unzip \
dirmngr debhelper cmake mailutils dnsutils apt-utils dialog lame odbc-mariadb pkg-config libicu-dev gcc g++ make  

#Install Asterisk 20 LTS dependencies
sudo apt -y install git curl wget libnewt-dev libssl-dev libncurses5-dev subversion libsqlite3-dev build-essential libjansson-dev libxml2-dev uuid-dev

#Add universe repository and install subversion
sudo add-apt-repository universe
sudo apt update && sudo apt -y install subversion

#Download Asterisk 20 LTS tarball
# sudo apt policy asterisk
cd /usr/src/
sudo wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-20-current.tar.gz

#Extract the file
tar xvf asterisk-20-current.tar.gz
cd asterisk-20*/

#download the mp3 decoder library
sudo contrib/scripts/get_mp3_source.sh

#Ensure all dependencies are resolved
sudo contrib/scripts/install_prereq install

#Run the configure script to satisfy build dependencies
sudo ./configure  --libdir=/usr/lib64 --with-pjproject-bundled --with-jansson-bundled

#Setup menu options by running the following command:
make menuselect.makeopts
menuselect/menuselect --enable app_macro menuselect.makeopts
make menuselect

#Use arrow keys to navigate, and Enter key to select. On Add-ons select chan_ooh323 and format_mp3 . 
#On Core Sound Packages, select the formats of Audio packets. Music On Hold, select 'Music onhold file package' 
# select Extra Sound Packages
#Enable app_macro under Applications menu
#Change other configurations as required

#build Asterisk
sudo make

#Install Asterisk by running the command:
sudo make install

#Install configs and samples
sudo make samples
sudo make config

# Create a separate user and group to run asterisk services, and assign correct permissions:
groupadd asterisk
useradd -r -d /var/lib/asterisk -g asterisk asterisk
usermod -aG audio,dialout asterisk
chown -R asterisk.asterisk /etc/asterisk
chown -R asterisk.asterisk /var/lib/asterisk
chown -R asterisk.asterisk /var/log/asterisk
chown -R asterisk.asterisk /var/spool/asterisk
chown -R asterisk.asterisk /usr/lib64/asterisk

#Set Asterisk default user to asterisk:
sed -i 's|#AST_USER|AST_USER|' /etc/default/asterisk
sed -i 's|#AST_GROUP|AST_GROUP|' /etc/default/asterisk

sed -i 's|;runuser|runuser|' /etc/asterisk/asterisk.conf
sed -i 's|;rungroup|rungroup|' /etc/asterisk/asterisk.conf

echo "/usr/lib64" >> /etc/ld.so.conf.d/x86_64-linux-gnu.conf
sudo ldconfig

# Problem: # *reference: https://www.clearhat.org/post/a-fix-for-apt-install-asterisk-on-ubuntu-18-04
# radcli: rc_read_config: rc_read_config: can't open /etc/radiusclient-ng/radiusclient.conf: No such file or directory
# Solution
sed -i 's";\[radius\]"\[radius\]"g' /etc/asterisk/cdr.conf
sed -i 's";radiuscfg => /usr/local/etc/radiusclient-ng/radiusclient.conf"radiuscfg => /etc/radcli/radiusclient.conf"g' /etc/asterisk/cdr.conf
sed -i 's";radiuscfg => /usr/local/etc/radiusclient-ng/radiusclient.conf"radiuscfg => /etc/radcli/radiusclient.conf"g' /etc/asterisk/cel.conf

# Enable asterisk service to start on system boot
sudo systemctl daemon-reload
sudo systemctl enable asterisk
sudo systemctl restart asterisk

#Test to see if it connect to Asterisk CLI
sudo asterisk -rvv

#open http ports and ports 5060,5061 in ufw firewall
sudo ufw allow 5060/udp
sudo ufw allow 5060/tcp
sudo ufw allow 10000:20000/udp

