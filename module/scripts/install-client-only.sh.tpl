#!/usr/bin/env bash
set -e

# Install packages
sudo apt-get update -y
sudo apt-get install -y curl unzip python-pip

pip install awscli

EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
EC2_REGION="`echo \"$${EC2_AVAIL_ZONE}\" | sed 's/[a-z]$//'`"

mkdir -p ~/.aws
echo "[default]
region = $${EC2_REGION}" > ~/.aws/config

# Download Vault into some temporary directory
curl -L "${download_url}" > /tmp/vault.zip

# Unzip it
cd /tmp
sudo unzip vault.zip
sudo mv vault /usr/local/bin
sudo chmod 0755 /usr/local/bin/vault
sudo chown root:root /usr/local/bin/vault