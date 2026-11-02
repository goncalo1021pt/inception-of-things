#!/usr/bin/env bash
set -Eeuo pipefail

command -v kubectl >/dev/null 2>&1 || {
  printf 'Error: kubectl is required.\n' >&2
  exit 1
}

password="$(
  kubectl get secret argocd-initial-admin-secret -n argocd \
    -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode
)"

printf 'Argo CD URL: https://localhost:8080\n'
printf 'Username: admin\n'
printf 'Password: %s\n\n' "${password}"
printf 'Keep this process running and press Ctrl+C when finished.\n'
kubectl port-forward service/argocd-server -n argocd 8080:443
