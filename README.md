

<div align="center">

![logo](./resources/logo.png)

<h1>lampone</h1>

My self hosted cloud, available at [cocointhe.cloud](https://cocointhe.cloud).

<br>


![nodes](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fnodes_count&style=for-the-badge&color=purple)
![pods](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fpods_count&style=for-the-badge&color=purple)
![cluster power](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fcluster_power_draw&style=for-the-badge&color=ffda1e)
<br>
![cluster uptime](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fcluster_uptime_days&style=for-the-badge&color=blue)
![cluster version](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fkubernetes_version&style=for-the-badge&color=blue)
![flux version](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fflux_version&style=for-the-badge&color=blue)
<br>
![cluster cpu](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fcluster_cpu_usage&style=for-the-badge)
![cluster ram](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fcluster_memory_usage&style=for-the-badge)
![nfs disk](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fnfs_disk_usage&style=for-the-badge)
![cluster temp](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fcluster_temperature&style=for-the-badge)

</div>

- [Hardware](#hardware)
  - [Bill of materials](#bill-of-materials)
  - [3D printed parts](#3d-printed-parts)
- [Software](#software)
  - [Requirements](#requirements)
  - [OS](#os)
  - [Creating the cluster](#creating-the-cluster)
  - [Deploying the stack](#deploying-the-stack)
- [Other bits and pieces](#other-bits-and-pieces)
  - [Cloudflare tunnel alternative w/ a VPS](#cloudflare-tunnel-alternative-w-a-vps)
  - [SOPS setup](#sops-setup)
  - [OIDC-based ssh access w/ opkssh](#oidc-based-ssh-access-w-opkssh)
  - [Staging env](#staging-env)
  - [Backup strategy](#backup-strategy)
    - [restic setup](#restic-setup)
    - [garage config](#garage-config)
    - [velero restore process](#velero-restore-process)



## Hardware

This is what the cluster looks like:

<div align="center">

![cluster](./resources/cluster.png)
</div>

### Bill of materials

What it's made of:

- 3 [raspberry pi 4 (8Go)](https://www.raspberrypi.com/products/raspberry-pi-4-model-b/)
- 1 [gigabit ethernet 5 ports switch](https://www.tp-link.com/home-networking/soho-switch/tl-sg105/)
- 1 [1To lexar ES3 usb SSD](https://www.lexar.com/products/Lexar-ES3-Portable-SSD/)
- 1 [80mm fan](https://www.thermalright.com/product/tl-8015w/)
- 3 very short cat6 ethernet cables
- a [3d printed rack](https://github.com/k0rventen/lampone/tree/main/resources/3d)
- some m3 threaded inserts and screws

### 3D printed parts

The rack is a remix of [this one](https://makerworld.com/en/models/180806-raspberry-pi-4-5-mini-server-rack-case). I've included the [stls here](https://github.com/k0rventen/lampone/tree/main/resources/3d) that I remixed/designed, aka the vented sleds for the PI4 and the SSD, and the side fan mount.


## Software

Here is a top view diagram of the main components:

![architecture](./resources/arch.png)

The Kubernetes cluster is deployed with [k3s](https://github.com/k3s-io/k3s).

The cluster state is handled by [fluxcd](https://fluxcd.io/), based on what's in this repo.

In `k8s/` there are 3 main folders:
- `flux`, the entrypoint used by the flux controller for synchronizing the cluster. Main 'apps' are declared here.
  The interval for the source GitRepo is set to `1m`, so changes will be picked up within a minute or so.
- `infra` represents what's needed for the cluster to function:
  - a [nfs-server](https://github.com/k0rventen/docker-nfs-server) + [csi-nfs-driver](https://github.com/kubernetes-csi/csi-driver-nfs) for handling persistent volumes,
  - an IngressController with [Traefik](https://github.com/traefik/traefik), one private (listens on local lan), one "public",
  - [cert-manager](https://github.com/cert-manager/cert-manager) for certificates management of my domain,
  - [kube-vip](https://github.com/kube-vip/kube-vip) for managing the cluster's VIP.  
  - [rathole](https://github.com/rathole-org/rathole) for exposing part of my services to the outside world ([see here](#cloudflare-tunnel-alternative-w-a-vps)),
  - [tailscale-operator](https://github.com/tailscale/tailscale/tree/main/cmd/k8s-operator/deploy) for accessing my private services from wherever (using a subnet route) and for my cluster services to access my offsite backup server
  - [system-upgrade-controller](https://github.com/rancher/system-upgrade-controller) for managing k8s upgrades directly in the cluster using CRDs.
  - a [renovate](https://github.com/renovatebot/renovate) cronjob to create PR for components updates (w/ auto merging when it's a patch level update and other rules)
  - [velero](https://velero.io/docs/v1.17/) + [garage](https://garagehq.deuxfleurs.fr/) for daily, local backups of the cluster (if an app fails and borks its files).
  - a [restic](https://github.com/restic/restic) cronjob that create a remote backup of the whole nfs dir (in case the server catches on fire) for DR situation,
  - [kyverno](https://kyverno.io/) for enforcing policies in the cluster,
  - [goldilocks](https://github.com/FairwindsOps/goldilocks) for automatic adjustments of limits/requests,
  - a [vcluster](https://www.vcluster.com/docs/vcluster/) where I do all my pre production testing, see [here](#staging-env).

- `apps`, the actual services running on the cluster:
  - [adguard](https://github.com/AdguardTeam/AdGuardHome) for DNS/DHCP
  - [gitea](https://github.com/go-gitea/gitea) for local git and CI/CD
  - [paperless-ngx](https://github.com/paperless-ngx/paperless-ngx) for my important files
  - [immich](https://github.com/immich-app/immich) for photos backups and sync
  - [vaultwarden](https://github.com/dani-garcia/vaultwarden) as my passwords manager
  - [filebrowser](https://github.com/gtsteffaniak/filebrowser) for file sharing
  - [glance](https://github.com/glanceapp/glance) as my internet homepage
  - [kromgo](https://github.com/kashalls/kromgo) for exposing prom stats publicly
  - [pocketid](https://github.com/pocket-id/pocket-id) as an OIDC provider
  - [atuin](https://github.com/atuinsh/atuin) for my centralized shell history
  - [uptime kuma](https://github.com/louislam/uptime-kuma) as a simple availability dashboard
  - [n8n](https://github.com/n8n-io/n8n) for basic automation workflows
  - [bytestash](https://github.com/jordan-dalby/ByteStash) for remembering short code/iaac snippets 
  - [grafana](https://github.com/grafana/grafana) + [prometheus](https://github.com/prometheus/prometheus) + [loki](https://github.com/grafana/loki) for monitoring the cluster,
  - [grist](https://github.com/gristlabs/grist-core) for a modern take on spreadsheets,
  - and some other stuff like a blog , static sites, etc..

I try to adhere to gitops/automation principles.
Some things aren't automated but it's mainly toil (one-time-things during setup etc..).
99% of the infrastructure should be deployable by following these instructions (assuming data and encryption keys are known).

### Requirements
- [ansible](https://docs.ansible.com/): infrastructure automation
- [flux](https://fluxcd.io/flux/): cluster state mgmt
- [sops](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age/): encryption
- [git](https://git-scm.com/): change management
- [gitleaks](https://github.com/gitleaks/gitleaks): secret detection as a pre-commit hook
- velero-cli: manage backups and restores from the CLI
- vcluster-cli: connect/pause/resume/reset the vcluster 
```

# install everything needed
brew install git ansible fluxcd/tap/flux sops age gitleaks loft-sh/tap/vcluster velero

# tell git where to find its hooks
git config core.hooksPath .githooks
```

### OS

The 3 rasps are running standard [Raspberry Pi OS Lite 64b](https://www.raspberrypi.com/software/operating-systems/). From there unnecessary packages are removed (dphys-swapfile, avahi-daemon, modemmanager and some others). 


### Creating the cluster

The bootstrapping is done using [ansible](https://docs.ansible.com/). The playbook will simply install k3s on all the nodes.

It is assumed that a ssh key auth is configured on the nodes (ssh-copy-id <ip>),
with passwordless sudo (`<user> ALL=(ALL) NOPASSWD: ALL` in visudo).

```
cd ansible
ansible-playbook -i inventory.yaml -l lampone cluster-install.yaml
```


### Deploying the stack

1. Get a github token and set an env var:
    ```fish
    export GITHUB_TOKEN=xxx
    ```

2. Enter some commands
    ```fish
    # pre create the decryption key
    kubectl create ns flux-system
    kubectl create secret generic sops-age --namespace=flux-system --from-file=age.agekey

    # bootstrap flux
    flux bootstrap github \
                  --owner=k0rventen \
                  --repository=lampone \
                  --branch=main \
                  --path=./k8s/flux
    ```

3. From here, Flux will create everything that is declared in `k8s/`, decrypt what's secret using the private key, and keep the stack in sync.


## Other bits and pieces

### Cloudflare tunnel alternative w/ a VPS

I previously used Cloudflare Tunnels to expose some apps to WAN without opening ports on my ISP router (and also being behind CGNAT).
Due to concerns regarding their ability to decrypt traffic at the edge (as they provision their own cert for the domain), I switched to [rathole](https://github.com/rathole-org/rathole) + a VPS. I'm currently renting one at [ByteHosting](https://bytehosting.cloud/index) in Germany. The 'server' side on the VPS forwards all the traffic from port 80/443 to the client running in my cluster, which then forwards everything to my dedicated traefik instance, which handles SSL and routing.

Here is the compose for the VPS:

```yaml
services:
  rathole:
    image: rapiz1/rathole:v0.5.0
    restart: always
    ports:
      - 80:80
      - 443:443
      - 2333:2333
    volumes:
      - ./server.toml:/app/config.toml
    command: --server /app/config.toml
```

And an example server config file:

```toml
[server]
bind_addr = "0.0.0.0:2333" # `2333` specifies the port that rathole listens for clients
default_token = "verylongtoken"

[server.services.traefik_https]
bind_addr = "0.0.0.0:443"

[server.services.traefik_http]
bind_addr = "0.0.0.0:80"
```


### SOPS setup

This assume you have the decryption key `age.agekey`, and the env var configured:

```
SOPS_AGE_KEY_FILE=age.agekey
```

If you want to encrypt an already created file (eg a k8s Secret spec):

```
sops encrypt -i <file.yaml>
```

If you want to edit inline a encrypted file (eg modify a value in a encrypted Secret/Configmap) using $EDITOR:

```
sops <file.yaml>
```

### OIDC-based ssh access w/ opkssh

Whenever possible, authentification is managed through my OIDC provider (pocketID). That's true for most of the services in the cluster, but also for accessing infrastructure-level stuff like my servers, using  [opkssh](https://github.com/openpubkey/opkssh).

1. On the OIDC provider, create a new app w/ a Public Client ID (no client secret).

2. On the client, install opkssh and in `.opk/config.yaml`, add the provider w/ the public client id as per the doc.

3. On the servers, install using the script:
    ```bash
    wget -qO- "https://raw.githubusercontent.com/openpubkey/opkssh/main/scripts/install-linux.sh" | sudo bash
    ```
    Add a provider in `/etc/opk/providers`, then add a user to the policy with `sudo opkssh add local_user oidc_email  https://oidc-provider`. This means that the user with `oidc_email` will be able to log in as `local_user`.

4. On the client, do a `opkssh login` then ssh should be seamless.

### Staging env

My staging environment is managed through [vcluster](https://github.com/loft-sh/vcluster). 
A virtual cluster is deployed inside my actual cluster, and has access to the ingressclass and storageclass of the underlying cluster. The flux controller can deploy resources in the vcluster by specifying the kubeconfig to use if necessary (see the `staging/deploy.yaml` file).

This allows a isolated cluster for testing things like new versions of various software, deploying new CRDs or testing RBAC rules or NetPols, and other cluster-wide changes without impacting the production environment. 

Quick commands:

```bash
# connect and switch kubeconfig
vcluster connect vcluster

# disconnect
vcluster disconnect

# destroy the vcluster
vcluster delete vcluster

# and recreate from scratch 
flux reconcile hr -n staging vcluster
```


### Backup strategy

I try to follow a 3-2-1 backup rule. The 'live' data is on the nfs ssd.
It's backed up daily onto the same ssd (mainly for rollbacks and potential local re-deployments).
For disaster-recovery situations, it's also backed up daily onto a HDD offsite, which can be accessed through my tailnet.

#### restic setup
The backup tool is [restic](https://restic.net/). It's deployed as a cronjob in the cluster. It launches a custom script that runs the local backup as well as the remote one (which requires commands before and after to mount the external disk on the remote side.). Here are the commands used to create the restic repos before deploying the cronjob:

1. local repo

```
cd /nfs
restic init nfs-backups
```

2. remote repo

Create a `mnt-backup.mount` systemd service on the remote server to mount/umount the backup disk
```
coco@remote_server:~ $ cat /etc/systemd/system/mnt-backup.mount
[Unit]
Description=Restic Backup External Disk mount

[Mount]
What=/dev/disk/by-label/backup
Where=/mnt/backup
Type=ext4
Options=defaults

[Install]
WantedBy=multi-user.target
```

Init the repo from the nfs server (this assumes passwordless ssh auth):
```
restic init -r sftp:<remote_server_ip>:/mnt/backup/nfs-backups
```

#### garage config

To configure garage as an s3 backend for velero, the following commands shall be ran on the garage container:

```sh
k exec garage-xx -- /garage status
k exec garage-xx -- /garage layout assign -z dc1 -c 1G node_id
k exec garage-xx -- /garage layout apply --version 1
k exec garage-xx -- /garage bucket create velero
k exec garage-xx -- /garage key create velero
k exec garage-xx -- /garage bucket allow --read --write --owner velero  --key velero
```

The key and secret printed when running `key create` can be reported in velero's config.

#### velero restore process

To create a one shot backup of an app:

```
velero backup create groceries -l app=groceries -n backups
```

Check its status:

```
velero backup describe groceries -n backups --details
```

To restore it:

```sh
# suspend the flux resource
flux suspend hr -n cloud groceries

# scale down the deployment
k scale --replicas 0 deploy groceries -n cloud

# delete the pvc (necessary for velero to recreate it and restore its content through kopia)
k delete pvc groceries-data -n cloud

# restore
velero restore create --from-backup groceries

# wait until done
velero restore describe groceries --details
```