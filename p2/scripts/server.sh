#!/bin/bash
set -e

apt-get update
apt-get install -y -q curl
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -s - \
	--node-ip=192.168.56.110 \
	--tls-san=192.168.56.110 \
	--flannel-iface=eth1
kubectl apply -f /vagrant/confs/
kubectl rollout status deployment/app1 --timeout=180s
kubectl rollout status deployment/app2 --timeout=180s
kubectl rollout status deployment/app3 --timeout=180s
echo "P2 apps deployed."
