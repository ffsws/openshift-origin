#!/bin/bash

echo $(date) " - Starting Script"

# install updates
yum update -y

# install the following base packages
yum install -y  wget git zile nano net-tools docker-1.13.1\
				bind-utils iptables-services \
				bridge-utils bash-completion \
				kexec-tools sos psacct openssl-devel \
				httpd-tools NetworkManager \
				python-cryptography python2-pip python-devel  python-passlib \
				java-1.8.0-openjdk-headless

#install epel
yum -y install epel-release

# Disable the EPEL repository globally so that is not accidentally used during later steps of the installation
sed -i -e "s/^enabled=1/enabled=0/" /etc/yum.repos.d/epel.repo

systemctl | grep "NetworkManager.*running"
if [ $? -eq 1 ]; then
	systemctl start NetworkManager
	systemctl enable NetworkManager
fi

# install the packages for Ansible
yum -y --enablerepo=epel install pyOpenSSL

curl -o ansible.rpm https://releases.ansible.com/ansible/rpm/release/epel-7-x86_64/ansible-2.6.5-1.el7.ans.noarch.rpm
yum -y --enablerepo=epel install ansible.rpm
yum -y install cloud-utils-growpart.noarch
yum -y update --exclude=WALinuxAgent
systemctl restart dbus

echo $(date) " - System updates successfully installed"

# Only install Ansible and pyOpenSSL on Master-0 Node
# python-passlib needed for metrics


echo $(date) " - Installing Ansible, pyOpenSSL and python-passlib"
yum -y --enablerepo=epel install pyOpenSSL python-passlib



# Grow Root File System
echo $(date) " - Grow Root FS"

rootdev=`findmnt --target / -o SOURCE -n`
rootdrivename=`lsblk -no pkname $rootdev`
rootdrive="/dev/"$rootdrivename
name=`lsblk  $rootdev -o NAME | tail -1`
part_number=${name#*${rootdrivename}}

growpart $rootdrive $part_number -u on
xfs_growfs $rootdev

if [ $? -eq 0 ]
then
    echo $(date) " - Root File System successfully extended"
else
    echo $(date) " - Root File System failed to be grown"
	exit 20
fi


# Create thin pool logical volume for Docker
echo $(date) " - Creating thin pool logical volume for Docker and staring service"

DOCKERVG=$( parted -m /dev/sda print all 2>/dev/null | grep unknown | grep /dev/sd | cut -d':' -f1 )

echo "DEVS=${DOCKERVG}" >> /etc/sysconfig/docker-storage-setup
echo "VG=docker-vg" >> /etc/sysconfig/docker-storage-setup
docker-storage-setup
if [ $? -eq 0 ]
then
   echo "Docker thin pool logical volume created successfully"
else
   echo "Error creating logical volume for Docker"
   exit 5
fi

# Enable and start Docker services

systemctl enable docker
systemctl start docker

echo $(date) " - Script Complete"
