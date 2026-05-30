#!/bin/bash
set -e

apt-get update -qq
apt-get install -y -q curl

echo "Installing K3s..."
curl -sfL https://get.k3s.io | \
  K3S_KUBECONFIG_MODE="644" \
  INSTALL_K3S_EXEC="--node-ip=192.168.56.110 --flannel-iface=eth1" \
  sh -

echo "Waiting for K3s to be ready..."
timeout 120 bash -c 'until kubectl get nodes 2>/dev/null | grep -q " Ready"; do sleep 2; done'

echo "Applying manifests..."
kubectl apply -f /vagrant/confs/apps.yaml

echo "Waiting for deployments..."
kubectl rollout status deployment/deploy-app1 --timeout=120s
kubectl rollout status deployment/deploy-app2 --timeout=120s
kubectl rollout status deployment/deploy-app3 --timeout=120s

echo ""
echo "Done. Test with:"
echo "  curl -H 'Host: app1.com' 192.168.56.110"
echo "  curl -H 'Host: app2.com' 192.168.56.110"
echo "  curl 192.168.56.110"
