#!/usr/bin/env bash
# Bonus: local GitLab (official Helm chart, namespace "gitlab") replaces GitHub
# as the Git source of Argo CD. Everything from Part 3 keeps working.
set -Eeuo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-iot-bonus}"
ARGOCD_VERSION="${ARGOCD_VERSION:-v3.4.2}"
ARGOCD_POLL_INTERVAL="${ARGOCD_POLL_INTERVAL:-30s}"
GITLAB_CHART_VERSION="${GITLAB_CHART_VERSION:-}"   # empty = latest published chart
GITLAB_HOST="${GITLAB_HOST:-gitlab.localhost}"
GITLAB_PROJECT="${GITLAB_PROJECT:-root/gfontao-iot}"
TARGET_REVISION="${GIT_TARGET_REVISION:-main}"
APP_PATH="${GIT_APP_PATH:-manifests}"

# Argo CD reaches GitLab through the in-cluster service; the host uses ${GITLAB_HOST}.
INTERNAL_REPO_URL="http://gitlab-webservice-default.gitlab.svc:8181/${GITLAB_PROJECT}.git"
EXTERNAL_REPO_URL="http://${GITLAB_HOST}/${GITLAB_PROJECT}.git"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BONUS_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
GITLAB_VALUES="${BONUS_DIR}/confs/gitlab-values.yaml"
GITLAB_DEPS="${BONUS_DIR}/confs/gitlab-deps.yaml"
APPLICATION_TEMPLATE="${BONUS_DIR}/confs/argocd/application.yaml.tpl"
REPOSITORY_TEMPLATE="${BONUS_DIR}/confs/argocd/repository-secret.yaml.tpl"
APP_MANIFESTS="${BONUS_DIR}/confs/dev"

log() {
  printf '\n\033[1;34m==> %s\033[0m\n' "$*"
}

die() {
  printf '\nError: %s\n' "$*" >&2
  exit 1
}

for command_name in docker k3d kubectl helm git curl sed; do
  command -v "${command_name}" >/dev/null 2>&1 \
    || die "${command_name} is required. Run bonus/scripts/install.sh first."
done
for required_file in "${GITLAB_VALUES}" "${GITLAB_DEPS}" "${APPLICATION_TEMPLATE}" "${REPOSITORY_TEMPLATE}"; do
  [[ -f "${required_file}" ]] || die "Missing ${required_file}."
done
docker info >/dev/null 2>&1 \
  || die "Docker is not available to this user. Start Docker and run 'newgrp docker'."

# *.localhost resolves to loopback in curl/git/browsers; warn early if it does not.
resolve_status=0
curl -s -o /dev/null -m 3 "http://${GITLAB_HOST}/" || resolve_status=$?
if [[ "${resolve_status}" -eq 6 ]]; then
  die "${GITLAB_HOST} does not resolve. Run: echo '127.0.0.1 ${GITLAB_HOST}' | sudo tee -a /etc/hosts"
fi

if k3d cluster list --no-headers 2>/dev/null | awk '{print $1}' | grep -Fxq "${CLUSTER_NAME}"; then
  log "Using existing K3d cluster ${CLUSTER_NAME}"
else
  log "Creating K3d cluster ${CLUSTER_NAME}"
  k3d cluster create "${CLUSTER_NAME}" \
    --servers 1 \
    --agents 1 \
    --port "8888:30080@loadbalancer" \
    --port "80:80@loadbalancer" \
    --wait
fi
kubectl config use-context "k3d-${CLUSTER_NAME}" >/dev/null

# K3s installs Traefik (and its CRDs) asynchronously. GitLab's chart asks the cluster
# which Traefik CRDs exist, so Traefik must be fully up before GitLab is installed.
log "Waiting for the Traefik ingress controller"
timeout 600 bash -c 'until kubectl -n kube-system get deployment traefik >/dev/null 2>&1; do sleep 5; done'
kubectl -n kube-system rollout status deployment/traefik --timeout=300s
kubectl wait --for=condition=Established crd/ingressroutetcps.traefik.io --timeout=2m

log "Creating the required namespaces"
for namespace in gitlab argocd dev; do
  kubectl create namespace "${namespace}" --dry-run=client -o yaml | kubectl apply -f -
done

log "Deploying PostgreSQL and Redis for GitLab (no longer bundled in the chart)"
for secret_name in gitlab-postgresql gitlab-redis; do
  if ! kubectl get secret "${secret_name}" -n gitlab >/dev/null 2>&1; then
    kubectl create secret generic "${secret_name}" -n gitlab \
      --from-literal=password="$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)"
  fi
done
kubectl apply -f "${GITLAB_DEPS}"
kubectl rollout status statefulset/postgresql -n gitlab --timeout=5m
kubectl rollout status statefulset/redis -n gitlab --timeout=5m

log "Installing GitLab (official Helm chart, ${GITLAB_CHART_VERSION:-latest})"
helm repo add gitlab https://charts.gitlab.io >/dev/null 2>&1 || true
helm repo update gitlab >/dev/null
chart_version_args=()
[[ -n "${GITLAB_CHART_VERSION}" ]] && chart_version_args=(--version "${GITLAB_CHART_VERSION}")
helm upgrade --install gitlab gitlab/gitlab \
  --namespace gitlab \
  --values "${GITLAB_VALUES}" \
  "${chart_version_args[@]}" \
  --wait --timeout 25m
helm list -n gitlab

log "Waiting for the GitLab web interface at http://${GITLAB_HOST}"
timeout 600 bash -c "until [[ \"\$(curl -s -o /dev/null -m 5 -w '%{http_code}' http://${GITLAB_HOST}/users/sign_in)\" == 200 ]]; do sleep 5; done" \
  || die "GitLab did not become reachable at http://${GITLAB_HOST}."

gitlab_password="$(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab \
  -o jsonpath='{.data.password}' | base64 --decode)"
[[ -n "${gitlab_password}" ]] || die "Could not read the GitLab root password."
git_auth_url="http://root:${gitlab_password}@${GITLAB_HOST}/${GITLAB_PROJECT}.git"

if git ls-remote "${git_auth_url}" HEAD 2>/dev/null | grep -q .; then
  log "GitLab project ${GITLAB_PROJECT} already has content, leaving it untouched"
else
  log "Creating GitLab project ${GITLAB_PROJECT} and pushing the v1 manifests"
  work_dir="$(mktemp -d)"
  trap 'rm -rf "${work_dir}"' EXIT
  mkdir -p "${work_dir}/${APP_PATH}"
  cp "${APP_MANIFESTS}"/*.yaml "${work_dir}/${APP_PATH}/"
  git -C "${work_dir}" init -q -b "${TARGET_REVISION}"
  git -C "${work_dir}" -c user.name=gfontao -c user.email=gfontao@localhost add .
  git -C "${work_dir}" -c user.name=gfontao -c user.email=gfontao@localhost \
    commit -q -m "initial manifests: wil42/playground v1"
  git -C "${work_dir}" push -q "${git_auth_url}" "${TARGET_REVISION}"
fi

log "Installing Argo CD ${ARGOCD_VERSION}"
kubectl apply --server-side --force-conflicts -n argocd \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=2m
kubectl rollout status deployment/argocd-server -n argocd --timeout=5m
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=5m

# Poll Git every ~30s instead of the default ~3min (+ jitter), and shorten the
# repo-server's branch cache, so the live v1 -> v2 switch shows up quickly.
log "Setting Argo CD Git polling interval to ${ARGOCD_POLL_INTERVAL}"
kubectl patch configmap argocd-cm -n argocd --type merge -p \
  "{\"data\":{\"timeout.reconciliation\":\"${ARGOCD_POLL_INTERVAL}\",\"timeout.reconciliation.jitter\":\"0s\"}}"
kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p \
  "{\"data\":{\"reposerver.revision.cache.expiration\":\"${ARGOCD_POLL_INTERVAL}\"}}"
kubectl rollout restart statefulset/argocd-application-controller -n argocd
kubectl rollout restart deployment/argocd-repo-server -n argocd
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=5m
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=5m

escape_sed_replacement() {
  printf '%s' "$1" | sed 's/[&|\\]/\\&/g'
}

log "Giving Argo CD credentials for the private GitLab project"
sed \
  -e "s|__REPO_URL__|$(escape_sed_replacement "${INTERNAL_REPO_URL}")|g" \
  -e "s|__GITLAB_PASSWORD__|$(escape_sed_replacement "${gitlab_password}")|g" \
  "${REPOSITORY_TEMPLATE}" | kubectl apply -f -

log "Registering the GitOps application (source: local GitLab)"
sed \
  -e "s|__REPO_URL__|$(escape_sed_replacement "${INTERNAL_REPO_URL}")|g" \
  -e "s|__TARGET_REVISION__|$(escape_sed_replacement "${TARGET_REVISION}")|g" \
  -e "s|__APP_PATH__|$(escape_sed_replacement "${APP_PATH}")|g" \
  "${APPLICATION_TEMPLATE}" | kubectl apply -f -

log "Waiting for Argo CD to synchronize the application"
if kubectl wait application/iot-app -n argocd \
  --for=jsonpath='{.status.sync.status}'=Synced --timeout=5m \
  && kubectl rollout status deployment/playground -n dev --timeout=5m \
  && timeout 120 bash -c 'until curl -sf -m 3 http://localhost:8888/ | grep -q "\"status\":\"ok\""; do sleep 2; done'; then
  log "Bonus is ready"
  printf 'Application: http://localhost:8888\n'
  printf 'GitLab:      http://%s  (user root, password: bash bonus/scripts/credentials.sh)\n' "${GITLAB_HOST}"
  printf 'Git remote:  %s\n' "${EXTERNAL_REPO_URL}"
  printf 'Argo CD UI:  run bash bonus/scripts/credentials.sh\n'
else
  printf '\nThe cluster is running, but the first sync from GitLab did not finish.\n' >&2
  kubectl describe application/iot-app -n argocd >&2 || true
  exit 1
fi
