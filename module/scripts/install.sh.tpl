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

# Setup the configuration
cat <<EOF >/tmp/vault-config
${config}
EOF
sudo mv /tmp/vault-config /usr/local/etc/vault-config.json

# Setup the init script
cat <<EOF >/tmp/upstart
description "Vault server"

start on runlevel [2345]
stop on runlevel [!2345]

respawn

script
  if [ -f "/etc/service/vault" ]; then
    . /etc/service/vault
  fi

  # Make sure to use all our CPUs, because Vault can block a scheduler thread
  export GOMAXPROCS=`nproc`

  exec /usr/local/bin/vault server \
    -config="/usr/local/etc/vault-config.json" \
    \$${VAULT_FLAGS} \
    >>/var/log/vault.log 2>&1
end script
EOF
sudo mv /tmp/upstart /etc/init/vault.conf

# Extra install steps (if any)
${extra-install}

# Start Vault
sudo start vault
