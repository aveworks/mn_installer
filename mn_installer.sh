#!/bin/bash
clear
#define vars for node
#these come from poseidon.pirl.io  
#-------Change the values below to influence how the script sets up your node and firewall------#

#this one is on your masternode page, and is unique for each masternode you have
#replace with your own values from poseidon 
## https://poseidon.pirl.io/accounts/masternodes-list-private/
MASTERNODE="----"

#this one is on your account page, and is the only one for your account
## https://poseidon.pirl.io/accounts/settings/
TOKEN=""



###((((( highly recommended you change this! ))))))###
#change ssh port to (recommended range is 1025-65535) 
#if you change this from the default value of port 22, 
# then the script will update your box to run ssh on the new port, and configure that value in the firewall

SSHD_PORT="22"    #(recommended range is 1025-65535)
#DO NOT USE PORT 30303

#important, ssh will only be allowed through firewall to everyone, only 
#if you do not set a static ip below. if you have a static ip then all ports will be allowed from it

#username you want the service to run as, if you want it to run as root, leave root
#if you want it to run as pirl put in pirl. no spaces allowed, and all lower case please.
#this user will not be used as a login user, so no password will be set.
RUNAS_USER="pirl"      #recommended username is pirl or root



######################################################################
########################## No editing below this #####################
######################################################################
#first, check the tokens
if [ "$MASTERNODE" = "----" ]
  then
  echo Please set your master node token from poseidon and run again
  exit 1
fi

if [ "$TOKEN" = "" ]
  then
  echo Please set your account token from poseidon.pirl.io and run again
  exit 2
fi



#check sshd port
if [ "$SSHD_PORT" -eq "30303" ]
  then
  echo "you are not allowed to use port 30303, pick something else for ssh"
  exit 2
fi
if [ "$SSHD_PORT" -eq "22" ]
  then
  echo sshd port default, and is 22
  echo will not change service
  sleep 1
fi

#check if username already exists,(if not we will make it later)
#if so, does it have a valid home dir for chain storage?
CREATEUSERNAME=0
getent passwd $RUNAS_USER > /dev/null 
if [ $? -eq 0 ]; then
    echo "User $RUNAS_USER exists"
    homedir=$( getent passwd "$RUNAS_USER" | cut -d: -f6 )
    if [ ! -d $homedir ]
      then
      echo "existing user has no home dir, or its not available. exiting."
      exit 4
    fi
 else
 echo "user $RUNAS_USER not found, will create"
CREATEUSERNAME=1
 sleep 1
fi

echo "OK, initial sanity checks look ok, proceeding"
echo "next step Creating service username if needed in 10 seconds"
sleep 5
echo "4"
sleep 1
echo "3"
sleep 1
echo "2"
sleep 1
echo "1"
sleep 1 

############### create the user if needed #################
###########################################################
###create the user if needed. just a run as user, not a login user,
###but they must have a home dir for the chain storage

if [ "$CREATEUSERNAME" -eq "1" ]
   then
   getent passwd $RUNAS_USER > /dev/null || useradd -r -m -s /usr/sbin/nologin -c "pirl masternode user" $RUNAS_USER
fi

#make sure its was created
getent passwd $RUNAS_USER > /dev/null 
if [ $? -eq 0 ]; then
    echo "User $RUNAS_USER created"
    homedir=$( getent passwd "$RUNAS_USER" | cut -d: -f6 )
    if [ ! -d $homedir ]
      then
      echo "New users home dir created as well @ $homedir"
    fi
 else
 echo "user $RUNAS_USER not found, tried to create but failed. stopping"
 exit 4
fi

echo "next step installing the masternode binary in 10 seconds"
sleep 5
echo "4"
sleep 1
echo "3"
sleep 1
echo "2"
sleep 1
echo "1"
sleep 1

############# grab the node binary and chmod ############################
#########################################################################
###if we got this far then the user exists, we will store the binary as a system file
###the chain will end up being stored on this users home dir, at /home/username/.pirl/
##make sure its not running if for reason the service is already there, do clean up
## incase it was run again  for some reason

systemctl stop pirlnode 2>/dev/null 1>/dev/null
if [ -e /usr/local/bin/pirl-linux-amd6 ]
  then
  rm -f /usr/local/bin/pirl-linux-amd64 2>/dev/null
fi
#get pirl node
echo "downloading latest PIRL Masternode"
wget -O /usr/local/bin/pirl-linux-amd64 http://release.pirl.io/downloads/masternode/linux/pirl-linux-amd64
downloadresult=$?
chmod 0755 /usr/local/bin/pirl-linux-amd64
chmodresult=$?

#double check download and perms
if [ "$downloadresult" -ne "0" ] || [ "$chmodresult" -ne "0" ]
  then
  echo "error happened downloading the node from http://release.pirl.io/downloads/masternode/linux/pirl-linux-amd64"
  echo "or trying to chmod it to 0755 at location /usr/local/bin/pirl-linux-amd64"
  exit 6
fi

#check the files md5sum to make sure it was not corrupted in transit
#pending md5file creation on repo

echo "next step updating or installing systemd service in 10 seconds"
sleep 5
echo "4"
sleep 1
echo "3"
sleep 1
echo "2"
sleep 1
echo "1"
sleep 1


############ populate files for systemd service #########
#########################################################
echo "[Unit]
Description=Pirl Master Node

[Service]
EnvironmentFile=/etc/pirlnode-env

Type=simple
User=$RUNAS_USER
Group=$RUNAS_USER

ExecStart=/usr/local/bin/pirl-linux-amd64
Restart=always

[Install]
WantedBy=default.target
">/etc/systemd/system/pirlnode.service

echo "MASTERNODE=\"$MASTERNODE\"
TOKEN=\"$TOKEN\"
">/etc/pirlnode-env

#setup a little link for monitoring to be an easier command
echo "journalctl -f -u pirlnode">/usr/local/bin/monitor
chmod 0755 /usr/local/bin/monitor

###reload in case it was there before, and now could be changed
systemctl daemon-reload

####enable the node
systemctl enable pirlnode

###start the node
systemctl start pirlnode

#echo -e "\n\n can monitor with journalctl --unit=pirlnode -f \n\n"


#default ports for pirlnode
ufw allow 30303/tcp
ufw allow 30303/udp

#allow all outgoing
# ufw default allow outgoing

clear
#show the status
ufw status


echo "all done!"
echo ""
echo ""
echo "commands you can run now:"
echo "firewall status command = ufw status"
echo "service status  command = systemctl status pirlnode"
echo "service logs    command = journalctl -f -u pirlnode  -or-  monitor"

exit 0
