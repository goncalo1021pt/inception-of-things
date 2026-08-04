#!/bin/bash
set -e

apt-get update
apt-get install -y -q curl
echo "Waiting for K3S token from server..."
timeout 120 bash -c 'while [ ! -f /vagrant/k3s-token ]; do sleep 1; done'
K3S_TOKEN=$(cat /vagrant/k3s-token)
K3S_URL="https://192.168.56.110:6443"
curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sh -s - \
	--node-ip=192.168.56.111 \
	--flannel-iface=eth1
echo "K3S Agent started"
