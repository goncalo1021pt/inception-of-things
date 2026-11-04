#!/usr/bin/env bash
set -Eeuo pipefail

GITLAB_HOST="${GITLAB_HOST:-gitlab.localhost}"

command -v kubectl >/dev/null 2>&1 || {
  printf 'Error: kubectl is required.\n' >&2
  exit 1
}

printf '\n== Namespaces ==\n'
kubectl get namespaces gitlab argocd dev

printf '\n== GitLab pods ==\n'
kubectl get pods -n gitlab

printf '\n== GitLab web interface ==\n'
curl -s -o /dev/null -m 10 -w "http://${GITLAB_HOST}/users/sign_in -> HTTP %{http_code}\n" \
  "http://${GITLAB_HOST}/users/sign_in"

printf '\n== Argo CD application ==\n'
kubectl get application iot-app -n argocd
kubectl get application iot-app -n argocd \
  -o jsonpath='source: {.spec.source.repoURL} ({.spec.source.targetRevision}, {.spec.source.path}){"\n"}'

printf '\n== Development workload ==\n'
kubectl get deployment,pod,service -n dev

printf '\n== Deployed image ==\n'
kubectl get deployment playground -n dev \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

printf '\n== Application response ==\n'
curl --fail --show-error --silent --max-time 10 http://localhost:8888/
printf '\n'
