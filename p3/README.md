# Part 3 - K3d and Argo CD

This folder contains the setup for Part 3 of the project.

It creates:

- one local K3d cluster named `iot`;
- one `argocd` namespace for Argo CD;
- one `dev` namespace for the application;
- one Argo CD Application named `iot-app`;
- the `wil42/playground` application exposed at `http://localhost:8888`; and
- a GitOps flow where Argo CD deploys the app from this GitHub repository.

## Important: Linux vs Windows

Use the Linux VM workflow for the real project defense/evaluation.

The Windows workflow is only for local testing on your Windows machine with
Docker Desktop. It is useful to check that the cluster, Argo CD, and GitOps
deployment work before you repeat the setup inside the required Linux VM.

## Repository layout

```text
p3/
├── confs/
│   ├── argocd/
│   │   └── application.yaml.tpl
│   └── dev/
│       ├── deployment.yaml
│       ├── kustomization.yaml
│       └── service.yaml
└── scripts/
    ├── install.sh
    ├── setup.sh
    ├── verify.sh
    ├── argocd-ui.sh
    ├── cleanup.sh
    └── windows/
        ├── setup.ps1
        ├── verify.ps1
        ├── argocd-ui.ps1
        └── cleanup.ps1
```

Argo CD watches the Kubernetes manifests in:

```text
p3/confs/dev
```

## What K3d is doing

K3s is the lightweight Kubernetes distribution used by the project.

K3d runs K3s inside Docker containers. That makes it easy to create and delete
a local Kubernetes cluster for this part of the project.

The setup exposes the application like this:

```text
localhost:8888 -> K3d load balancer -> Kubernetes NodePort 30080 -> app port 8888
```

---

# Linux VM setup - required path

Use this path for the real project. The commands below assume an Ubuntu or
Debian VM.

Recommended VM size:

- 2 vCPUs;
- 4 GB RAM;
- 20 GB free disk space.

## 1. Install basic packages

Inside the Linux VM:

```bash
sudo apt-get update
sudo apt-get install -y git curl ca-certificates
```

## 2. Clone or pull the repository

If the repository is not cloned yet:

```bash
git clone https://github.com/YOUR_LOGIN/YOUR_REPOSITORY.git
cd YOUR_REPOSITORY
```

Example:

```bash
git clone https://github.com/Magalvo/IoT.git
cd IoT
```

If the repository is already cloned:

```bash
cd IoT
git pull
```

## 3. Check that Part 3 files exist

From the repository root:

```bash
ls p3
ls p3/scripts
ls p3/confs/dev
```

You should see the scripts and Kubernetes manifests.

## 4. Install Docker, K3d, and kubectl

Run the installer as your normal VM user, not as `root`:

```bash
bash p3/scripts/install.sh
```

The installer installs:

- Docker Engine;
- K3d v5.9.0;
- kubectl from the Kubernetes 1.32 stable channel.

If Docker was installed for the first time, refresh your group permissions:

```bash
newgrp docker
```

Then confirm Docker works without `sudo`:

```bash
docker info
```

## 5. Push the repository to public GitHub

The subject requires the Argo CD application to use a public GitHub repository.
The repository name must contain at least one team member login.

If this repository is already public and pushed, you can skip this step.

Otherwise:

```bash
git status
git add .
git commit -m "Set up IoT Part 3"
git branch -M main
git remote add origin https://github.com/YOUR_LOGIN/YOUR_REPOSITORY.git
git push -u origin main
```

For this project, the repository URL currently being tested is:

```text
https://github.com/Magalvo/IoT.git
```

## 6. Create the K3d cluster and install Argo CD

From the repository root, run:

```bash
bash p3/scripts/setup.sh https://github.com/YOUR_LOGIN/YOUR_REPOSITORY.git
```

Example:

```bash
bash p3/scripts/setup.sh https://github.com/Magalvo/IoT.git
```

Optional full form:

```bash
bash p3/scripts/setup.sh REPOSITORY_URL main p3/confs/dev
```

The setup script will:

1. create the K3d cluster named `iot`;
2. create the `argocd` namespace;
3. create the `dev` namespace;
4. install Argo CD v3.4.2;
5. create the Argo CD Application;
6. wait for the first sync; and
7. expose the app at `http://localhost:8888`.

## 7. Validate the Linux setup

Run:

```bash
bash p3/scripts/verify.sh
curl http://localhost:8888/
```

Expected result:

```json
{"status":"ok", "message": "v1"}
```

Useful manual checks:

```bash
kubectl get namespaces
kubectl get pods -n argocd
kubectl get deployment,pod,service -n dev
kubectl get application iot-app -n argocd
k3d cluster list
```

The important state is:

- namespace `argocd` exists;
- namespace `dev` exists;
- Argo CD Application `iot-app` is `Synced` and `Healthy`;
- deployment `playground` is running in namespace `dev`;
- `http://localhost:8888/` returns `v1`.

## 8. Open the Argo CD UI on Linux

Run this and keep the terminal open:

```bash
bash p3/scripts/argocd-ui.sh
```

Then open:

```text
https://localhost:8080
```

Accept the local self-signed certificate warning.

Login:

```text
username: admin
password: printed by the script
```

## 9. Demonstrate the v1 to v2 GitOps update

Edit:

```text
p3/confs/dev/deployment.yaml
```

Change:

```yaml
image: wil42/playground:v1
```

to:

```yaml
image: wil42/playground:v2
```

Commit and push:

```bash
git add p3/confs/dev/deployment.yaml
git commit -m "Deploy playground v2"
git push
```

Argo CD checks Git automatically. Wait for the rollout:

```bash
kubectl rollout status deployment/playground -n dev --timeout=5m
curl http://localhost:8888/
```

Expected result:

```json
{"status":"ok", "message": "v2"}
```

If you want to force Argo CD to check Git immediately, run:

```bash
kubectl annotate application iot-app -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite
```

Then check again:

```bash
kubectl rollout status deployment/playground -n dev --timeout=5m
curl http://localhost:8888/
```

## 10. Clean up the Linux VM cluster

To delete the local K3d cluster:

```bash
bash p3/scripts/cleanup.sh
```

---

# Windows setup - local testing only

Use this path only to test on your Windows machine.

This validates the same general behavior, but the official project should still
be run in the Linux VM.

## 1. Install prerequisites on Windows

Install:

- Git for Windows;
- Docker Desktop.

In Docker Desktop:

1. start Docker Desktop;
2. make sure it is using Linux containers;
3. wait until Docker says it is running.

You do not need to install K3d manually. The Windows setup script downloads a
checksum-verified `k3d.exe` into:

```text
p3/.tools
```

That folder is ignored by Git.

Docker Desktop already provides `kubectl`, which the Windows scripts use.

## 2. Clone or pull the repository on Windows

Open PowerShell.

If the repository is not cloned yet:

```powershell
cd C:\Users\diogo.santos\Documents
git clone https://github.com/YOUR_LOGIN/YOUR_REPOSITORY.git
cd YOUR_REPOSITORY
```

Example:

```powershell
cd C:\Users\diogo.santos\Documents
git clone https://github.com/Magalvo/IoT.git
cd IoT
```

If the repository is already cloned:

```powershell
cd C:\Users\diogo.santos\Documents\IoT
git pull
```

## 3. Confirm Docker Desktop is ready

From PowerShell:

```powershell
docker info
```

Check the operating system type:

```powershell
docker info --format '{{.OSType}}'
```

Expected result:

```text
linux
```

If it says `windows`, switch Docker Desktop to Linux containers.

## 4. Run the Windows setup

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File p3/scripts/windows/setup.ps1 `
  -RepoUrl https://github.com/YOUR_LOGIN/YOUR_REPOSITORY.git
```

Example:

```powershell
powershell -ExecutionPolicy Bypass -File p3/scripts/windows/setup.ps1 `
  -RepoUrl https://github.com/Magalvo/IoT.git
```

Optional full form:

```powershell
powershell -ExecutionPolicy Bypass -File p3/scripts/windows/setup.ps1 `
  -RepoUrl https://github.com/YOUR_LOGIN/YOUR_REPOSITORY.git `
  -TargetRevision main `
  -AppPath p3/confs/dev
```

The setup script will:

1. check Docker Desktop;
2. download and verify K3d if needed;
3. create the K3d cluster named `iot`;
4. create the `argocd` namespace;
5. create the `dev` namespace;
6. install Argo CD v3.4.2;
7. create the Argo CD Application; and
8. expose the app at `http://localhost:8888`.

## 5. Validate the Windows setup

Run:

```powershell
powershell -ExecutionPolicy Bypass -File p3/scripts/windows/verify.ps1
```

Expected important results:

```text
iot-app is Synced and Healthy
the deployed image is wil42/playground:v1
the application returns {"status":"ok", "message": "v1"}
```

You can also test directly:

```powershell
curl.exe http://localhost:8888/
```

Expected result:

```json
{"status":"ok", "message": "v1"}
```

## 6. Open the Argo CD UI on Windows

Run this and keep the PowerShell window open:

```powershell
powershell -ExecutionPolicy Bypass -File p3/scripts/windows/argocd-ui.ps1
```

Then open:

```text
https://localhost:8080
```

Accept the local self-signed certificate warning.

Login:

```text
username: admin
password: printed by the script
```

## 7. Demonstrate the v1 to v2 GitOps update on Windows

Edit:

```text
p3/confs/dev/deployment.yaml
```

Change:

```yaml
image: wil42/playground:v1
```

to:

```yaml
image: wil42/playground:v2
```

Commit and push:

```powershell
git add p3/confs/dev/deployment.yaml
git commit -m "Deploy playground v2"
git push
```

Ask Argo CD to check Git immediately:

```powershell
kubectl annotate application iot-app -n argocd `
  argocd.argoproj.io/refresh=hard --overwrite
```

Wait for the rollout:

```powershell
kubectl rollout status deployment/playground -n dev --timeout=5m
curl.exe http://localhost:8888/
```

Expected result:

```json
{"status":"ok", "message": "v2"}
```

## 8. Clean up the Windows test cluster

To delete the local K3d cluster:

```powershell
powershell -ExecutionPolicy Bypass -File p3/scripts/windows/cleanup.ps1
```

---

# Troubleshooting

## Docker is not available

Check that Docker is running:

```bash
docker info
```

On Linux, if Docker was just installed, run:

```bash
newgrp docker
```

On Windows, start Docker Desktop and confirm it is using Linux containers.

## Argo CD does not sync

Check that:

- the GitHub repository is public;
- the latest files were pushed;
- the repository URL passed to the setup script is correct;
- the manifests exist at `p3/confs/dev`;
- the branch is `main`, unless you passed a different `TargetRevision`.

Useful command:

```bash
kubectl describe application iot-app -n argocd
```

## The app does not answer on localhost:8888

Check the workload:

```bash
kubectl get deployment,pod,service -n dev
kubectl rollout status deployment/playground -n dev --timeout=5m
```

Check that the K3d cluster was created with the port mapping:

```bash
k3d cluster list
```

On Windows, the setup script recreates an incomplete `iot` cluster if it is
missing the K3d load balancer.

## Reset everything and try again

Linux:

```bash
bash p3/scripts/cleanup.sh
bash p3/scripts/setup.sh https://github.com/YOUR_LOGIN/YOUR_REPOSITORY.git
```

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File p3/scripts/windows/cleanup.ps1
powershell -ExecutionPolicy Bypass -File p3/scripts/windows/setup.ps1 `
  -RepoUrl https://github.com/YOUR_LOGIN/YOUR_REPOSITORY.git
```
