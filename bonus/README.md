# Bonus: GitLab instead of GitHub

Part 3, but the Git server is a **local GitLab** running in the cluster (namespace
`gitlab`) instead of GitHub. Argo CD pulls the manifests from it and everything from
Part 3 keeps working, including the v1 → v2 switch.

```text
host: git push ──► http://gitlab.localhost ─(k3d LB :80 → Traefik)─► GitLab  [ns gitlab]
                                                                       ▲
                                  Argo CD [ns argocd] pulls, in-cluster│ http://gitlab-webservice-default.gitlab.svc:8181/root/gfontao-iot.git
                                       │ syncs
                                       ▼
host: curl localhost:8888 ◄── wil42/playground [ns dev]
```

It uses its own k3d cluster `iot-bonus` and does not depend on Part 3. Part 3 and the
bonus both use port 8888, so run only one at a time (`bash p3/scripts/cleanup.sh` or
`bash bonus/scripts/cleanup.sh` first).

## Layout

```text
bonus/
├── confs/
│   ├── gitlab-values.yaml              # trimmed official GitLab Helm chart values
│   ├── gitlab-deps.yaml                # PostgreSQL + Redis (no longer bundled in the chart)
│   ├── argocd/application.yaml.tpl     # Argo CD Application (same as p3)
│   ├── argocd/repository-secret.yaml.tpl  # credentials Argo CD uses for GitLab
│   └── dev/                            # v1 manifests pushed to GitLab
└── scripts/
    ├── install.sh       # Docker, k3d, kubectl, Helm
    ├── setup.sh         # everything, one command
    ├── credentials.sh   # GitLab/Argo CD logins + Argo CD UI
    ├── verify.sh        # state check
    └── cleanup.sh       # delete the cluster
```

## Requirements

- Linux with Docker. **~8 GB free RAM and 4 CPUs**; in a VM give it 12 GB.
- `*.localhost` must resolve to loopback (it does in curl, git and browsers). If it
  does not, `setup.sh` says so and the fix is `echo '127.0.0.1 gitlab.localhost' | sudo tee -a /etc/hosts`.
- Port 80 and 8888 free.

## Run

```bash
bash bonus/scripts/install.sh     # once; uses sudo
bash bonus/scripts/setup.sh       # ~15 min the first time (GitLab is heavy)
bash bonus/scripts/verify.sh
```

`setup.sh`:

1. creates the k3d cluster `iot-bonus` (ports `80` and `8888`);
2. creates the namespaces `gitlab`, `argocd`, `dev`;
3. waits for k3s' Traefik, deploys PostgreSQL and Redis (`confs/gitlab-deps.yaml`), then installs
   the **latest** official GitLab chart (`charts.gitlab.io`, currently chart 10.x = GitLab 19.x) with
   the values in `confs/gitlab-values.yaml` (CE, plain HTTP, Traefik ingress);
4. creates the private project `root/gfontao-iot` by pushing the v1 manifests;
5. installs Argo CD and a repository Secret with the GitLab credentials, so Argo CD can read
   the private project through the in-cluster service address;
6. registers the Application `iot-app` and waits until `http://localhost:8888` answers.

To pin a chart version: `GITLAB_CHART_VERSION=<version> bash bonus/scripts/setup.sh`.

## Design notes (what GitLab 19.x changed)

- Since chart 10 the chart **no longer bundles PostgreSQL, Redis or MinIO**: we run a small
  PostgreSQL 17 and Valkey (Redis) StatefulSet in the `gitlab` namespace. PostgreSQL gets
  `max_locks_per_transaction=512`, otherwise GitLab's schema load fails with "out of shared memory".
- No object storage: only Git hosting is needed, so artifacts/LFS/uploads/packages are disabled.
- Chart 10 defaults to the Gateway API + Envoy. We switch to a plain `Ingress` served by k3d's Traefik.
- The toolbox (backups) and gitlab-shell (SSH) are disabled: all access is HTTP.
- Traefik must be fully up *before* installing the chart (it detects Traefik CRDs at install time).

## Logins

```bash
bash bonus/scripts/credentials.sh
```

prints the GitLab login (`root` and the generated password, UI at `http://gitlab.localhost`)
and the Argo CD login, then opens the Argo CD UI on `https://localhost:8080`
(`ARGOCD_UI_PORT=8443` to change the port).

## Demo: v1 → v2 through GitLab

```bash
curl http://localhost:8888/                       # {"status":"ok", "message": "v1"}
PW=$(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath='{.data.password}' | base64 -d)
git clone http://root:$PW@gitlab.localhost/root/gfontao-iot.git && cd gfontao-iot
grep image manifests/deployment.yaml              # v1
sed -i 's/wil42\/playground:v1/wil42\/playground:v2/g' manifests/deployment.yaml
git add . && git commit -m "v2" && git push
# Argo CD polls GitLab every ~30 s
kubectl rollout status deployment/playground -n dev
curl http://localhost:8888/                       # {"status":"ok", "message": "v2"}
```

Automated: `bash tests/bonus-test.sh` (state) and `bash tests/bonus-test.sh --roundtrip`
(also pushes v2 and back to v1 and times it).

## Cleanup

```bash
bash bonus/scripts/cleanup.sh
```

## Troubleshooting

| Symptom | Check |
|---|---|
| `setup.sh` stops at "does not resolve" | add `127.0.0.1 gitlab.localhost` to `/etc/hosts` |
| Migrations job `Error`, Postgres log says "out of shared memory" | `max_locks_per_transaction` too low in `gitlab-deps.yaml` |
| GitLab pods `Pending`/`OOMKilled` | not enough RAM: `kubectl top nodes`, `free -h` |
| Application `ComparisonError` / auth | `kubectl get secret gitlab-repo -n argocd`; password must match `gitlab-gitlab-initial-root-password` |
| `git push` rejected | project is private: use `http://root:<password>@gitlab.localhost/...` |
| Port 80 or 8888 already in use | stop the other cluster or service |
