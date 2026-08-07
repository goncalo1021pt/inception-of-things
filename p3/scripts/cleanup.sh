#!/usr/bin/env bash
set -Eeuo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-iot}"

command -v k3d >/dev/null 2>&1 || {
  printf 'Error: k3d is required.\n' >&2
  exit 1
}

if k3d cluster list --no-headers 2>/dev/null | awk '{print $1}' | grep -Fxq "${CLUSTER_NAME}"; then
  k3d cluster delete "${CLUSTER_NAME}"
else
  printf 'Cluster %s does not exist.\n' "${CLUSTER_NAME}"
fi
