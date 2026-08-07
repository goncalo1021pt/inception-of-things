#!/usr/bin/env bash
set -Eeuo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-iot}"
ARGOCD_VERSION="${ARGOCD_VERSION:-v3.4.2}"
REPO_URL="${1:-${GIT_REPO_URL:-}}"
TARGET_REVISION="${2:-${GIT_TARGET_REVISION:-main}}"
APP_PATH="${3:-${GIT_APP_PATH:-p3/confs/dev}}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
P3_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
APPLICATION_TEMPLATE="${P3_DIR}/confs/argocd/application.yaml.tpl"

log() {
  printf '\n\033[1;34m==> %s\033[0m\n' "$*"
}

die() {
  printf '\nError: %s\n' "$*" >&2
  exit 1
}

for command_name in docker k3d kubectl curl sed; do
  command -v "${command_name}" >/dev/null 2>&1 \
    || die "${command_name} is required. Run p3/scripts/install.sh first."
done

[[ -f "${APPLICATION_TEMPLATE}" ]] || die "Missing ${APPLICATION_TEMPLATE}."
[[ -n "${REPO_URL}" ]] \
  || die "Usage: $0 https://github.com/OWNER/REPOSITORY.git [REVISION] [APP_PATH]"
[[ "${REPO_URL}" =~ ^https://github\.com/[^/]+/[^/]+(\.git)?$ ]] \
  || die "Use the HTTPS URL of a public GitHub repository."
[[ "${TARGET_REVISION}" != *$'\n'* && "${APP_PATH}" != *$'\n'* ]] \
  || die "Revision and application path must be single-line values."

docker info >/dev/null 2>&1 \
  || die "Docker is not available to this user. Start Docker and run 'newgrp docker'."

if k3d cluster list --no-headers 2>/dev/null | awk '{print $1}' | grep -Fxq "${CLUSTER_NAME}"; then
  log "Using existing K3d cluster ${CLUSTER_NAME}"
else
  log "Creating K3d cluster ${CLUSTER_NAME}"
  k3d cluster create "${CLUSTER_NAME}" \
    --servers 1 \
    --agents 1 \
    --port "8888:30080@loadbalancer" \
    --wait
fi

kubectl config use-context "k3d-${CLUSTER_NAME}" >/dev/null

log "Creating the required namespaces"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

log "Installing Argo CD ${ARGOCD_VERSION}"
kubectl apply --server-side --force-conflicts -n argocd \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=2m
kubectl rollout status deployment/argocd-server -n argocd --timeout=5m
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=5m

escape_sed_replacement() {
  printf '%s' "$1" | sed 's/[&|\\]/\\&/g'
}

rendered_application="$(mktemp)"
trap 'rm -f "${rendered_application}"' EXIT
sed \
  -e "s|__REPO_URL__|$(escape_sed_replacement "${REPO_URL}")|g" \
  -e "s|__TARGET_REVISION__|$(escape_sed_replacement "${TARGET_REVISION}")|g" \
  -e "s|__APP_PATH__|$(escape_sed_replacement "${APP_PATH}")|g" \
  "${APPLICATION_TEMPLATE}" >"${rendered_application}"

log "Registering the GitOps application"
kubectl apply -f "${rendered_application}"

log "Waiting for Argo CD to synchronize the application"
if kubectl wait application/iot-app -n argocd \
  --for=jsonpath='{.status.sync.status}'=Synced --timeout=5m \
  && kubectl rollout status deployment/playground -n dev --timeout=5m; then
  log "Part 3 is ready"
  printf 'Application: http://localhost:8888\n'
  printf 'Argo CD UI: run bash p3/scripts/argocd-ui.sh\n'
else
  printf '\nThe cluster is running, but the first Git sync did not finish.\n' >&2
  printf 'Check that the repository is public, pushed, and contains %s.\n' "${APP_PATH}" >&2
  kubectl describe application/iot-app -n argocd >&2 || true
  exit 1
fi
