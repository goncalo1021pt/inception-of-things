#!/usr/bin/env bash
set -Eeuo pipefail

command -v kubectl >/dev/null 2>&1 || {
  printf 'Error: kubectl is required.\n' >&2
  exit 1
}

printf '\n== Namespaces ==\n'
kubectl get namespaces argocd dev

printf '\n== Argo CD application ==\n'
kubectl get application iot-app -n argocd

printf '\n== Argo CD pods ==\n'
kubectl get pods -n argocd

printf '\n== Development workload ==\n'
kubectl get deployment,pod,service -n dev

printf '\n== Deployed image ==\n'
kubectl get deployment playground -n dev \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

printf '\n== Application response ==\n'
curl --fail --show-error --silent --max-time 10 http://localhost:8888/
printf '\n'
