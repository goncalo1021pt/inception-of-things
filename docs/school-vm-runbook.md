# School VM runbook: full test run of Inception-of-Things

Instructions for a Claude Code session running **inside a Debian 13 VirtualBox
VM on a 42 school PC**. The user (Gonçalo) is present and will help with
anything that needs the school host, a password, or GitHub credentials.

## Goal

Prove that the mandatory part (p1, p2, p3) works end to end in the same kind of
environment the defense will use. **Test only**: do not redesign anything.

- Branch under test: `goncalo/delivery` of `https://github.com/goncalo1021pt/inception-of-things`
- p1 and p2 use **Vagrant + VirtualBox inside this VM** (nested virtualization).
- p3 uses **Docker + k3d** inside this VM.
- The bonus (GitLab) is not built yet. Ignore it.

## Rules for this session

1. **Do not change project files to make a test pass** without telling the user
   first. If something fails, diagnose it, propose the fix, and wait.
2. **Do not push** to any repository unless the user says so. The only push
   expected is the p3 v1→v2 demo, in step 7, and only with the user's go-ahead.
3. Run **p1 and p2 one at a time**: both use `192.168.56.110`. Always clean
   one before starting the other.
4. Long commands (`vagrant up`, `setup.sh`) take minutes. Run them in the
   background with a timeout and log to a file. Never let a hang go unnoticed.
5. Record every result in `~/iot-results.md` (see "Report" at the end).

## Reference numbers (developer laptop, no nesting)

| Step | Time | Expected test result |
|---|---|---|
| `make p1-up` | ~4 min | `make -C p1 test`: 10 passed, 0 failed |
| `make p2-up` | ~5 min | `make -C p2 test`: 14 passed, 0 failed |
| `p3/scripts/setup.sh` | ~2.5 min | `verify.sh` shows `v1`, `curl localhost:8888` answers right away |
| p3 `git push` v1→v2 | ~35–55 s until `curl` shows v2 | no manual refresh needed |

Nested virtualization is usually 2–3× slower. Slower is fine; failing is not.

---

## Step 0: Check the VM itself

The user creates this VM on the school host. The settings that matter:

- Debian 13 (trixie), amd64
- **4+ vCPUs, 12 GB RAM** (the GitLab bonus will need ~8 GB later), **60 GB disk**,
  stored in `goinfre`/`sgoinfre` if home space is small
- **Nested VT-x/AMD-V enabled**. The GUI checkbox is often greyed out, so the
  user runs this on the school host with the VM powered off:
  `VBoxManage modifyvm "<vm-name>" --nested-hw-virt on`
- BIOS boot or EFI **without Secure Boot** (Secure Boot blocks the unsigned
  `vboxdrv` kernel module)

Verify from inside the VM:

```bash
grep -cE 'vmx|svm' /proc/cpuinfo   # must be > 0, otherwise nested virt is OFF: stop and tell the user
nproc; free -h; df -h ~            # expect >=4 CPUs, >=12G RAM, >=40G free
. /etc/os-release; echo "$PRETTY_NAME"
sudo -v                            # user must have sudo
```

If the user has no sudo: they run `su -` then `usermod -aG sudo <user>`, then
log out and back in.

## Step 1: Base packages

```bash
sudo apt-get update
sudo apt-get install -y git make curl wget gnupg ca-certificates \
  build-essential dkms linux-headers-$(uname -r)
```

## Step 2: VirtualBox (Oracle repository)

```bash
wget -qO- https://www.virtualbox.org/download/oracle_vbox_2016.asc \
  | sudo gpg --dearmor -o /usr/share/keyrings/oracle-virtualbox-2016.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian trixie contrib" \
  | sudo tee /etc/apt/sources.list.d/virtualbox.list
sudo apt-get update
sudo apt-get install -y virtualbox-7.2
sudo usermod -aG vboxusers "$USER"
```

Verify:

```bash
VBoxManage --version          # the developer laptop used 7.2.6
lsmod | grep vboxdrv          # must be loaded
```

If `vboxdrv` is missing, run `sudo /sbin/vboxconfig` and read its error
(usually missing headers or Secure Boot).

## Step 3: Vagrant (HashiCorp repository)

```bash
wget -qO- https://apt.releases.hashicorp.com/gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release; echo $VERSION_CODENAME) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update
sudo apt-get install -y vagrant
vagrant --version             # the developer laptop used 2.4.9
```

If `apt-get update` says the `trixie` suite doesn't exist in the HashiCorp
repo, replace `trixie` with `bookworm` in that file and retry.

## Step 4: Get the code

```bash
git clone -b goncalo/delivery https://github.com/goncalo1021pt/inception-of-things.git ~/inception-of-things
cd ~/inception-of-things
git log --oneline -3          # note the commit hash in the report
```

## Step 5: Part 1 (2 VMs: K3s server and agent)

```bash
make p1-up                    # background + log, e.g.: timeout 2400 make p1-up > ~/p1-up.log 2>&1
make -C p1 test               # expect: 10 passed, 0 failed
```

Also show what the evaluator will look at:

```bash
cd p1
vagrant ssh gfontaoS  -c "kubectl get nodes -o wide"   # gfontaos (control-plane) + gfontaosw, both Ready, IPs .110/.111
vagrant ssh gfontaoSW -c "ip a show eth1"              # inet 192.168.56.111
cd ..
make p1-clean
```

## Step 6: Part 2 (1 VM: 3 apps behind an Ingress)

Only after `make p1-clean`.

```bash
make p2-up                    # background + log
make -C p2 test               # expect: 14 passed, 0 failed (includes 4 checks curling from this VM)
```

Manual check, exactly what the evaluator does:

```bash
curl -s -H "Host: app1.com" http://192.168.56.110 | grep -o "Hello from app[0-9]"   # app1
curl -s -H "Host: app2.com" http://192.168.56.110 | grep -o "Hello from app[0-9]"   # app2
curl -s http://192.168.56.110                     | grep -o "Hello from app[0-9]"   # app3
(cd p2 && vagrant ssh gfontaoS -c "kubectl get pods,ingress")                      # app2 has 3 pods
make p2-clean
```

## Step 7: Part 3 (k3d + Argo CD, GitOps from GitHub)

```bash
bash p3/scripts/install.sh    # installs Docker, k3d v5.9.0, kubectl 1.32 (uses sudo)
```

If Docker was just installed, this shell isn't in the `docker` group yet.
Either ask the user to log out and back in, or prefix the next commands with
`sg docker -c '...'`.

```bash
bash p3/scripts/setup.sh      # no arguments: uses github.com/goncalo1021pt/gfontao-iot, branch main, path manifests
bash p3/scripts/verify.sh     # namespaces argocd + dev, iot-app Synced/Healthy, image wil42/playground:v1
curl http://localhost:8888/   # {"status":"ok", "message": "v1"}
```

Argo CD UI (keeps running in the foreground):

```bash
bash p3/scripts/argocd-ui.sh                          # https://localhost:8080, user admin, password printed
ARGOCD_UI_PORT=8443 bash p3/scripts/argocd-ui.sh      # if 8080 is taken
```

**v1→v2 live switch: ask the user before doing this**, because it pushes to
GitHub. It needs GitHub credentials in the VM (`gh auth login`, or a personal
access token as the HTTPS password).

```bash
git clone https://github.com/goncalo1021pt/gfontao-iot.git ~/gfontao-iot && cd ~/gfontao-iot
grep image manifests/deployment.yaml                 # v1
sed -i 's/wil42\/playground:v1/wil42\/playground:v2/g' manifests/deployment.yaml
git add . && git commit -m "v2" && git push
# setup.sh makes Argo CD poll Git every ~30s (default would be ~3 min). To force it now:
kubectl annotate application iot-app -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl rollout status deployment/playground -n dev --timeout=5m
curl http://localhost:8888/                          # {"status":"ok", "message": "v2"}
```

Then **put the repo back to v1** (the defense must start from v1), with the
same sed reversed, then commit and push. Check that `curl` shows `v1` again.

Clean up:

```bash
cd ~/inception-of-things && bash p3/scripts/cleanup.sh
```

---

## Problems already found and fixed on this branch: don't re-fix them

| Symptom | Cause | Fix already in the code |
|---|---|---|
| p1 worker stuck on "Starting k3s-agent", server API timing out | 512 MB server RAM: K3s v1.36 thrashes swap | p1 server has 1024 MB (the subject allows 1024) |
| `make p2-up` succeeds but curl gets "Connection refused" for ~2 min | Traefik installs late (CRD race inside K3s) | `p2/scripts/server.sh` waits until app1 is actually served |
| First curl to `.110` hangs ~10–15 s right after p1 was destroyed | Host ARP cache still has the old VM's MAC | `p2/scripts/server.sh` sends a gratuitous ARP (`arping -U`) |
| Argo CD UI port-forward fails: "address already in use" | Something else on port 8080 | `ARGOCD_UI_PORT` override |
| v1→v2 push takes ~6 min to show up | Argo CD default polling (~3 min + jitter) plus the repo-server's 3 min branch cache | `setup.sh` sets both to 30 s |
| `curl localhost:8888` empty right after `setup.sh` says ready | Pod Ready slightly before the k3d load balancer forwards | `setup.sh` waits until the app actually answers |

## Troubleshooting nested virtualization

| Symptom | Likely cause | What to do |
|---|---|---|
| `VERR_VMX_NO_VMX` / "VT-x is not available" | Nested VT-x is off on the outer VM | User powers the VM off and runs `VBoxManage modifyvm "<vm>" --nested-hw-virt on` on the school host |
| `VERR_VMX_IN_VMX_ROOT_MODE` / "VT-x is being used by another hypervisor" | KVM modules loaded in this VM | `sudo modprobe -r kvm_intel kvm` (or `kvm_amd kvm`), then retry |
| "The IP address configured for the host-only network is not within the allowed ranges" | VirtualBox host-only range restriction | `echo '* 192.168.56.0/21' \| sudo tee /etc/vbox/networks.conf` |
| `vagrant up` waits forever at "Waiting for machine to boot" | Nested VM very slow, or nested virt off | Check `grep -c vmx /proc/cpuinfo`; `boot_timeout` is already 600 s |
| Worker never joins (p1) | Server out of memory / very slow | `vagrant ssh gfontaoS -c "free -m; uptime"`; report numbers before changing anything |
| Disk full | Vagrant boxes + VMs + Docker images | `df -h`; boxes live in `~/.vagrant.d/boxes`, VMs in `~/VirtualBox VMs` |

## Report

Write `~/iot-results.md` with:

- VM specs (`nproc`, `free -h`, `df -h ~`), CPU vendor (`grep -m1 -oE 'vmx|svm' /proc/cpuinfo`)
- Versions: Debian, VirtualBox, Vagrant, Docker, k3d, kubectl
- Commit hash tested
- For each part: duration of the up/setup step, test output (pass/fail counts), manual checks
- Every failure: exact error, the log excerpt, what you tried, the proposed fix
- Anything that was slow enough to worry about at a defense

Show the user the report at the end.
