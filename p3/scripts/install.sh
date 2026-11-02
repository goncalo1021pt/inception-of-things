#!/usr/bin/env bash
set -Eeuo pipefail

K3D_VERSION="${K3D_VERSION:-v5.9.0}"
KUBECTL_MINOR="${KUBECTL_MINOR:-1.32}"

log() {
  printf '\n\033[1;34m==> %s\033[0m\n' "$*"
}

die() {
  printf '\nError: %s\n' "$*" >&2
  exit 1
}

if [[ "${EUID}" -eq 0 ]]; then
  die "Run this script as the normal VM user; it invokes sudo when needed."
fi

command -v sudo >/dev/null 2>&1 || die "sudo is required."
[[ -r /etc/os-release ]] || die "Cannot identify the Linux distribution."

# shellcheck disable=SC1091
source /etc/os-release
case "${ID:-}" in
  ubuntu|debian) ;;
  *) die "Supported distributions are Ubuntu and Debian (detected: ${ID:-unknown})." ;;
esac

log "Installing base packages"
sudo apt-get update
sudo apt-get install -y ca-certificates curl git gnupg

if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker Engine from Docker's official repository"
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${ID}/gpg" \
    | sudo tee /etc/apt/keyrings/docker.asc >/dev/null
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  docker_codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
  [[ -n "${docker_codename}" ]] || die "Could not determine the distribution codename."
  architecture="$(dpkg --print-architecture)"

  sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/${ID}
Suites: ${docker_codename}
Components: stable
Architectures: ${architecture}
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  sudo apt-get update
  sudo apt-get install -y \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  log "Docker is already installed"
fi

sudo systemctl enable --now docker
sudo usermod -aG docker "${USER}"

if ! command -v k3d >/dev/null 2>&1; then
  log "Installing K3d ${K3D_VERSION}"
  curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh \
    | TAG="${K3D_VERSION}" bash
else
  log "K3d is already installed"
fi

if ! command -v kubectl >/dev/null 2>&1; then
  log "Installing kubectl from the Kubernetes ${KUBECTL_MINOR} stable channel"
  kubectl_version="$(curl -fsSL "https://dl.k8s.io/release/stable-${KUBECTL_MINOR}.txt")"
  machine_arch="$(uname -m)"
  case "${machine_arch}" in
    x86_64) kubectl_arch="amd64" ;;
    aarch64|arm64) kubectl_arch="arm64" ;;
    *) die "Unsupported CPU architecture for kubectl: ${machine_arch}" ;;
  esac

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' EXIT
  curl -fsSLo "${tmp_dir}/kubectl" \
    "https://dl.k8s.io/release/${kubectl_version}/bin/linux/${kubectl_arch}/kubectl"
  curl -fsSLo "${tmp_dir}/kubectl.sha256" \
    "https://dl.k8s.io/release/${kubectl_version}/bin/linux/${kubectl_arch}/kubectl.sha256"
  printf '%s  %s\n' "$(cat "${tmp_dir}/kubectl.sha256")" "${tmp_dir}/kubectl" \
    | sha256sum --check
  sudo install -o root -g root -m 0755 "${tmp_dir}/kubectl" /usr/local/bin/kubectl
else
  log "kubectl is already installed"
fi

log "Installed versions"
docker --version || sudo docker --version
k3d version
kubectl version --client

printf '\nInstallation complete. If Docker was just installed, run:\n\n'
printf '  newgrp docker\n\n'
