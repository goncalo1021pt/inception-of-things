# Inception-of-Things (IoT) — Quick Reference

## Repo Structure

```
/p1/      Vagrantfile + scripts/ + confs/
/p2/      Vagrantfile + scripts/ + confs/
/p3/      scripts/ + confs/
/bonus/   scripts/ + confs/
```

Scripts go in `scripts/`, Kubernetes manifests/config in `confs/`.
Evaluation runs on the evaluated group's machine.

---

## Part 1 — K3s and Vagrant

**Goal:** Two VMs managed by Vagrant, K3s installed on both.

### Machine specs

| Machine      | Hostname     | IP               | K3s role                    |
|---|---|---|---|
| Server       | `<login>S`   | `192.168.56.110` | controller (server mode)    |
| ServerWorker | `<login>SW`  | `192.168.56.111` | agent (worker mode)         |

- Resources: 1 CPU, 512 MB RAM (1024 MB acceptable)
- Dedicated IP on primary network interface
- SSH with no password on both machines
- `kubectl` must be installed
- Use latest stable version of your chosen Linux distro

### Vagrantfile structure (from subject)

```ruby
$> cat Vagrantfile
Vagrant.configure(2) do |config|
    [...]
    config.vm.box = REDACTED
    config.vm.box_url = REDACTED

    config.vm.define "wilS" do |control|
            control.vm.hostname = "wilS"
            control.vm.network REDACTED, ip: "192.168.56.110"
            control.vm.provider REDACTED do |v|
                v.customize ["modifyvm", :id, "--name", "wilS"]
                [...]
            end
            config.vm.provision :shell, :inline => SHELL
                [...]
            SHELL
            control.vm.provision "shell", path: REDACTED
    end
    config.vm.define "wilSW" do |control|
            control.vm.hostname = "wilSW"
            control.vm.network REDACTED, ip: "192.168.56.111"
            control.vm.provider REDACTED do |v|
                v.customize ["modifyvm", :id, "--name", "wilSW"]
                [...]
            end
            config.vm.provision "shell", inline: <<-SHELL
                [..]
            SHELL
            control.vm.provision "shell", path: REDACTED
    end
end
```

### Expected state — broken (only server, no worker joined yet)

```
[vagrant@wil5 ~]$ k get nodes -o wide
NAME    STATUS   ROLES                  AGE    VERSION       INTERNAL-IP      EXTERNAL-IP   OS-IMAGE         KERNEL-VERSION               CONTAINER-RUNTIME
wil5   Ready    control-plane,master   4h37   v1.21.4+k3s1  192.168.56.110   <none>        CentOS Linux 8   4.18.0-240.1.1.el8_3.x86_64  containerd://1.4.9-k3s1
[vagrant@wil5 ~]$ ifconfig eth1
eth1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.42.110  netmask 255.255.255.0  broadcast 192.168.42.255
        inet6 fe80::a00:27ff:fe79:56d8  prefixlen 64  scopeid 0x20<link>
        ether 08:00:27:79:56:d0  txqueuelen 1000  (Ethernet)
        RX packets 20  bytes 2427 (2.3 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 20  bytes 3762 (3.6 KiB)
        TX errors 0  dropped 0  carrier 0  collisions 0
```

### Expected state — correct (both nodes Ready, correct IPs)

```
[vagrant@wil5 ~]$ k get nodes -o wide
NAME     STATUS   ROLES                  AGE    VERSION       INTERNAL-IP      EXTERNAL-IP   OS-IMAGE         KERNEL-VERSION               CONTAINER-RUNTIME
wil5    Ready    control-plane,master   16h    v1.21.4+k3s1  192.168.56.110   <none>        CentOS Linux 5   4.18.0-240.1.1.el0_3.x86_64  containerd://1.4.9-k3s1
wilSW   Ready    <none>                 70s    v1.21.4+k3s1  192.168.56.111   <none>        CentOS Linux 0   4.18.0-240.1.1.el0_3.x86_64  containerd://1.4.9-k3s1
[vagrant@wilSW ~]$ ifconfig eth1
eth1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.42.111  netmask 255.255.255.0  broadcast 192.168.42.56.255
        inet6 fe00:a00:27ff:fea8:bc04  prefixlen 64  scopeid 0x20<link>
        ether 08:00:27:a8:bc:04  txqueuelen 1000  (Ethernet)
        RX packets 446  bytes 322199 (314.6 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 472  bytes 101181 (98.8 KiB)
        TX errors 0  dropped 0  carrier 0  collisions 0
```

> Modern distros use predictable interface names (`enp0s8`, `enp0s9`) instead of `eth0`/`eth1`. Use `ip a` to list interfaces or `ip a show <interface_name>` for a specific one.

---

## Part 2 — K3s and Three Simple Applications

**Goal:** One VM with K3s (server mode). Three web apps routed by Ingress on HTTP `Host` header.

### Machine

- Single VM, IP `192.168.56.110`, hostname `<login>S`
- K3s in server mode

### Routing rules

| Host header    | App served | Replicas |
|---|---|---|
| `app1.com`     | app1       | 1        |
| `app2.com`     | app2       | **3**    |
| *(any other)*  | app3       | 1        |

> The Ingress resource must exist and be shown during defense.

### Expected state — broken (pods stuck ContainerCreating)

```
[vagrant@wil5 ~]$ k get nodes -o wide
NAME    STATUS   ROLES                  AGE   VERSION       INTERNAL-IP      EXTERNAL-IP   OS-IMAGE         KERNEL-VERSION   CONTAINER-RUNTIME
wil5   Ready    control-plane,master    14m   v1.21.4+k3s1  192.168.56.110   <none>        CentOS Linux 8                    containerd://1.4.9-k3s1
[vagrant@wil5 ~]$ k get all -n kube-system
NAME                                             READY   STATUS             RESTARTS   AGE
pod/metrics-server-86cbb8457f-09zx4             0/1     ContainerCreating  0          14m
pod/local-path-provisioner-5ff76fc89d-p7g5b     0/1     ContainerCreating  0          14m
pod/coredns-7448499f4d-jwlpt                    0/1     ContainerCreating  0          14m
pod/helm-install-traefik-wkn88                  0/1     ContainerCreating  0          14m
pod/helm-install-traefik-crd-82sq2              0/1     ContainerCreating  0          14m

NAME                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                  AGE
service/kube-dns         ClusterIP   10.43.0.10      <none>        53/UDP,53/TCP,9153/TCP    14m
service/metrics-server   ClusterIP   10.43.89.169    <none>        443/TCP                   14m

NAME                                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/local-path-provisioner         0/1     1            0           14m
deployment.apps/coredns                        0/1     1            0           14m
deployment.apps/metrics-server                 0/1     1            0           14m

NAME                                                    DESIRED   CURRENT   READY   AGE
replicaset.apps/metrics-server-86cbb8457f               1         1         0       14m
replicaset.apps/local-path-provisioner-5ff76fc89d       1         1         0       14m
replicaset.apps/coredns-7448499f4d                      1         1         0       14m

NAME                                    COMPLETIONS   DURATION   AGE
job.batch/helm-install-traefik          0/1           14m        14m
job.batch/helm-install-traefik-crd      0/1           14m        14m
```

### Expected state — correct (all Running, app2 has 3 replicas)

```
[vagrant@wil5 de]$ k get all
NAME                               READY   STATUS    RESTARTS   AGE
pod/app-two-6bc974bc98-qtjj7      1/1     Running   0          15m
pod/app-one-6fd76fc6f9-9h64n      1/1     Running   0          15m
pod/app-three-688f68bdcc-sm9rt    1/1     Running   0          15m
pod/app-two-6bc974bc98-n2wth      1/1     Running   0          15m
pod/app-two-6bc974bc98-qhp6p      1/1     Running   0          15m

NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/kubernetes     ClusterIP   10.43.0.1        <none>        443/TCP   16m
service/app-three      ClusterIP   10.43.229.156    <none>        80/TCP    15m
service/app-two        ClusterIP   10.43.193.160    <none>        80/TCP    15m
service/app-one        ClusterIP   10.43.171.213    <none>        80/TCP    4m45s

NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/app-two       3/3     3            3           15m
deployment.apps/app-three     1/1     1            1           15m
deployment.apps/app-one       1/1     1            1           15m

NAME                                      DESIRED   CURRENT   READY   AGE
replicaset.apps/app-one-6fd76fc6f9       1         1         1       15m
replicaset.apps/app-three-688f68bdcc     1         1         1       15m
replicaset.apps/app-two-6bc974bc90       1         1         3       15m

[vagrant@wil5 de]$ curl -H "Host:app2.com" 192.168.56.110
<!DOCTYPE html>
<html>
<head>
    <title>Hello Kubernetes!</title>
    <link rel="stylesheet" type="text/css" href="/css/Main.css">
    <link rel="stylesheet" href="https://fonts.googleapis.com/css?family=Ubuntu:300">
</head>
<body>
    <div class="main">
        <img src="/images/kubernetes.png"/>
        <div id="content">
Hello from app2.
        </div>
    </div>
    <div id="info">
        <table>
            <tr>
                <th>pod:</th>
                <td>app-two-6bc974bc98-qtjj7</td>
            </tr>
            <tr>
                <th>node:</th>
                <td>Linux (4.18.0-240.1.1.el8_3.x86_64)</td>
            </tr>
        </table>
    </div>
</body>
</html>
```

---

## Part 3 — K3d and Argo CD

**Goal:** K3d cluster (no Vagrant) with Argo CD doing GitOps. App auto-deployed and updated from a public GitHub repo.

### Requirements

- Install Docker + K3d (write an install script — it runs during defense)
- Know the difference: K3s = lightweight K8s; K3d = K3s running inside Docker containers
- Create a **public GitHub repository** with a team member's login in the name
- Push Kubernetes manifests (e.g. in a `manifests/` folder) to that repo

### Namespaces

| Namespace | Purpose                          |
|---|---|
| `argocd`  | Argo CD installation             |
| `dev`     | Application deployed by Argo CD  |

### Application options

**Option A — Wil's pre-made app:**
- Image: `wil42/playground` (Docker Hub)
- Port: `8888`
- Tags: `v1` and `v2` (find them in the TAG section on Docker Hub)

**Option B — your own app:**
- Must be a public Docker Hub image
- Tag two versions: `v1` and `v2` (versions must have visible differences)

### Expected state — namespaces and pod

```
$> k get ns
NAME    STATUS   AGE
[..]
argocd  Active   19h
dev     Active   19h
$> k get pods -n dev
NAME                              READY   STATUS    RESTARTS   AGE
wil-playground-65f745fdf4-d212r  1/1     Running   0          8m9s
$>
```

### Expected state — check version v1, then update to v2

```
$> cat deployment.yaml | grep v1
      - image: wil42/playground:v1
$> curl http://localhost:8888/
{"status":"ok", "message": "v1"}

$> sed -i 's/wil42\/playground:v1/wil42\/playground:v2/g' deployment.yaml
$> git add . && git commit -m "v2" && git push
[..]
    a773f39..999b9fe master -> master
$> cat deployment.yaml | grep v2
      - image: wil42/playground:v2
```

After Argo CD syncs:

```
$> curl http://localhost:8888/
{"status":"ok", "message": "v2"}
```

> During the defense you must perform this v1 → v2 switch live with the app you chose.

---

## Bonus — GitLab Integration

**Goal:** Replace GitHub with a self-hosted GitLab. Everything from Part 3 must keep working.

- GitLab runs locally (latest version from official source)
- Configure GitLab to integrate with the K3d cluster
- Create a dedicated namespace named `gitlab`
- Argo CD syncs from local GitLab instead of GitHub
- `helm` is allowed
- Store all bonus files in `/bonus/` at repo root
- Bonus is only evaluated if the mandatory part is **flawless**
