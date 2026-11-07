#!/bin/bash
set -e

apt-get update
apt-get install -y -q curl iputils-arping
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.37.2+k3s1" K3S_KUBECONFIG_MODE="644" sh -s - \
	--node-ip=192.168.56.110 \
	--tls-san=192.168.56.110 \
	--flannel-iface=eth1
kubectl apply -f /vagrant/confs/
kubectl rollout status deployment/app1 --timeout=180s
kubectl rollout status deployment/app2 --timeout=180s
kubectl rollout status deployment/app3 --timeout=180s
echo "Waiting for Traefik ingress controller..."
timeout 600 bash -c 'until kubectl -n kube-system get deployment traefik >/dev/null 2>&1; do sleep 5; done'
kubectl -n kube-system rollout status deployment/traefik --timeout=300s
timeout 120 bash -c 'until curl -s -H "Host: app1.com" http://192.168.56.110 | grep -q "Hello from app1"; do sleep 2; done'
# Announce this VM's MAC so the host drops any stale ARP entry left by a
# previous VM on the same IP (e.g. p1 destroyed right before p2 boots).
arping -U -c 3 -I eth1 192.168.56.110 >/dev/null || true
echo "P2 apps deployed and reachable through the ingress."
