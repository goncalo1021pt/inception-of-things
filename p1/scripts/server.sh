#!/bin/bash
set -e

apt-get update -qq
apt-get install -y -q curl

curl -sfL https://get.k3s.io | \
  K3S_KUBECONFIG_MODE="644" \
  INSTALL_K3S_EXEC="--node-ip=192.168.56.110 --flannel-iface=eth1" \
  sh -

echo "Waiting for token..."
timeout 120 bash -c 'while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do sleep 1; done'
cp /var/lib/rancher/k3s/server/node-token /vagrant/k3s-token
echo "Token copied."