#!/bin/bash
set -e

# Update and install necessary packages
apt-get update
apt-get install -y wget gnupg lsb-release openssh-server nano less

# Update package list and install  NFS
apt-get update
apt-get install -y nfs-kernel-server nfs-common

# Configure SSH
mkdir -p /var/run/sshd
echo 'root:changeme' | chpasswd
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

#Add directory to NFS exports
echo "/nfs *(rw,sync,no_subtree_check,no_root_squash)" > /etc/exports