#!/bin/bash
set -e

apt-get update -qq
apt-get install -y -q curl

IFACE=$(ip -o -4 addr show | awk '/192\.168\.56\.110/ {print $2}')

curl -sfL https://get.k3s.io | \
  K3S_KUBECONFIG_MODE="644" \
  INSTALL_K3S_EXEC="--node-ip=192.168.56.110 --flannel-iface=${IFACE}" \
  sh -
