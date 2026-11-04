#!/usr/bin/env bash
# Print the GitLab and Argo CD logins, then expose the Argo CD UI.
set -Eeuo pipefail

UI_PORT="${ARGOCD_UI_PORT:-8080}"
GITLAB_HOST="${GITLAB_HOST:-gitlab.localhost}"

command -v kubectl >/dev/null 2>&1 || {
  printf 'Error: kubectl is required.\n' >&2
  exit 1
}

gitlab_password="$(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab \
  -o jsonpath='{.data.password}' | base64 --decode)"
argocd_password="$(kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath='{.data.password}' | base64 --decode)"

printf 'GitLab URL:      http://%s\n' "${GITLAB_HOST}"
printf 'GitLab login:    root / %s\n\n' "${gitlab_password}"
printf 'Argo CD URL:     https://localhost:%s\n' "${UI_PORT}"
printf 'Argo CD login:   admin / %s\n\n' "${argocd_password}"
printf 'Keep this process running and press Ctrl+C when finished.\n'
kubectl port-forward service/argocd-server -n argocd "${UI_PORT}:443"
