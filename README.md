# inception-of-things

42 project: K3s, K3d and Argo CD. The subject is summarized in [docs/SUBJECT.md](docs/SUBJECT.md).

| Part | What | Directory |
|---|---|---|
| p1 | 2 Vagrant VMs (`gfontaoS`, `gfontaoSW`), K3s server + agent | [p1/](p1/) |
| p2 | 1 Vagrant VM, K3s, 3 apps routed by an Ingress on the `Host` header | [p2/](p2/) |
| p3 | k3d + Argo CD, GitOps from the public repo `goncalo1021pt/gfontao-iot` | [p3/](p3/README.md) |
| bonus | p3 with a local GitLab (namespace `gitlab`) instead of GitHub | [bonus/](bonus/README.md) |

## Usage

Every part has a Makefile with the same targets, reachable from the root as `make <part>-<target>`
(`part` = `p1`, `p2`, `p3`, `bonus`):

| Target | Does |
|---|---|
| `<part>-up` | build and start the part |
| `<part>-down` | stop it, keeping its state |
| `<part>-status` | show its state |
| `<part>-test` | run its checks (`tests/<part>-test.sh`) |
| `<part>-clean` | destroy it |
| `<part>-re` | `clean` + `up` |

```bash
make help            # all targets
make p2-up p2-test   # build part 2, then check it
make p3-roundtrip    # p3 checks + a live v1 -> v2 -> v1 push to GitHub (needs push credentials)
make bonus-roundtrip # bonus checks + the same switch through the local GitLab
make install         # Docker, k3d, kubectl, Helm (sudo). Vagrant and VirtualBox are installed separately
make check           # build, test and destroy every part in turn (~40 min)
make clean           # destroy everything
```

Per-part extras: `p1-ssh-server`, `p1-ssh-worker`, `p2-ssh`, `p2-hosts`, `p3-ui`, `bonus-ui` (Argo CD UI and logins).

Constraints: p1 and p2 both use `192.168.56.110`, and p3 and the bonus both publish port `8888`.
Run one of each pair at a time; `p3-up` and `bonus-up` refuse to start while the other is running.

## Requirements

- p1, p2: VirtualBox and Vagrant.
- p3, bonus: Docker (then `make install`). The bonus needs about 8 GB of free RAM.
- Test runs in a school VM: see [docs/school-vm-runbook.md](docs/school-vm-runbook.md).
