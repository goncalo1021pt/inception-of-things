# Part 2: K3s and three simple applications

Here's a breakdown of what Part 2 (folder `p2`) asks you to build.

## The goal
Set up **one** Vagrant VM running **K3s in server mode**, then deploy **3 web applications** on it. Which app you see depends on the `Host:` header (domain name) the client sends when hitting the VM's IP. This is the core lesson of Part 2: **Ingress-based host routing**.

## The hard requirements

| Requirement | Detail |
|---|---|
| **1 VM** | Only one machine this time (Part 1 had two). Distribution of your choice, **latest stable version**. |
| **K3s** | Installed in **server mode**. |
| **VM name** | Your login + `S` → e.g. `gpereirS` (your login appears to be `gpereir`). |
| **IP** | The VM must be reachable at **`192.168.56.110`**. |
| **3 apps** | Three web apps of your choice (any simple "hello"-type web server image works). |
| **App 2 = 3 replicas** | App 2 specifically must run **3 replicas**. Apps 1 and 3 are single replicas. |

## The routing rules (this is the heart of it)
A client makes a request to **`192.168.56.110`** and the response depends on the `Host` header:

- `Host: app1.com` → show **App 1**
- `Host: app2.com` → show **App 2**
- **Anything else / no host** → show **App 3** (the default)

You'd test it like:
```bash
curl -H "Host: app1.com" 192.168.56.110   # → app1
curl -H "Host: app2.com" 192.168.56.110   # → app2
curl 192.168.56.110                        # → app3 (default)
```

## What you actually need to write

Inside a new **`p2/`** folder:

1. **`Vagrantfile`** — defines one VM, hostname `gpereirS`, private network IP `192.168.56.110`, enough RAM/CPU (1–2GB / 1–2 CPU), and a provisioning script.
2. **Provisioning script** — installs K3s in server mode and applies your Kubernetes manifests. K3s ships with the **Traefik Ingress controller** built in, which is exactly what does the host-based routing for you.
3. **Kubernetes manifests** (YAML) — typically:
   - 3 **Deployments** (app1 = 1 replica, app2 = **3 replicas**, app3 = 1 replica)
   - 3 **Services** (ClusterIP, one per app)
   - 1 **Ingress** with three host rules (`app1.com`, `app2.com`, and a default backend → app3)

You can put all manifests in one file or split them; mounting them into the VM (e.g. via Vagrant's synced folder) and `kubectl apply`-ing them in the provision script is the clean approach.

## How the routing works under the hood
The single **Ingress** object maps hostnames to Services:
```
app1.com  ─┐
app2.com  ─┤── Traefik (built into K3s) ── routes by Host header ──> correct Service ──> Pods
(default) ─┘
```
Traefik listens on the node, reads the `Host` header, and forwards to the matching Service. The "default" rule (a rule with no host, or a default backend) catches everything else → app3.

## Key conceptual differences from Part 1
- **One VM** instead of two (no separate worker node required).
- The new skill is **Kubernetes resources** (Deployments, Services, Ingress) and **replicas**, rather than just getting a cluster up.
- App 2's **3 replicas** demonstrates that one Service load-balances across multiple Pods.

## Suggested `p2/` layout
```
p2/
├── Vagrantfile
├── scripts/
│   └── server.sh        # installs k3s + kubectl apply the manifests
└── confs/
    ├── app1.yaml        # Deployment + Service
    ├── app2.yaml        # Deployment (3 replicas) + Service
    ├── app3.yaml        # Deployment + Service
    └── ingress.yaml     # single Ingress, 3 host rules
```

A common trick for app images: use a small image like `paulbouwer/hello-kubernetes` (lets you set a custom message via env var) or three different simple images, so when you `curl` each host you can visibly tell them apart.
