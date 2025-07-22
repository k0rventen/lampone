

<div align="center">

![logo](./resources/logo.png)

<h1>lampone</h1>

My self hosted cloud, available at [cocointhe.cloud](https://cocointhe.cloud).

<br>


![sli](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Favailability_sli&style=for-the-badge&)
![cluster uptime](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fcluster_uptime_days&style=for-the-badge&color=blue)
<br>
![cluster version](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fkubernetes_version&style=for-the-badge&color=blue)
![nodes](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fnodes_count&style=for-the-badge&color=purple)
![pods](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fpods_count&style=for-the-badge&color=purple)
![cluster power](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fcluster_power_draw&style=for-the-badge&color=ffda1e)
<br>
![cluster cpu](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fcluster_cpu_usage&style=for-the-badge)
![cluster ram](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fcluster_memory_usage&style=for-the-badge)
![nfs disk](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fnfs_disk_usage&style=for-the-badge)
![cluster temp](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fcluster_temperature&style=for-the-badge)

</div>


## Hardware

This is what the cluster looks like:

<div align="center">

![cluster](./resources/cluster.gif)
</div>

What it's made of:

- 3 [raspberry pi 4 (8Go)](https://www.raspberrypi.com/products/raspberry-pi-4-model-b/)
- 1 [gigabit ethernet 5 ports switch](https://www.tp-link.com/home-networking/soho-switch/tl-sg105/)
- 1 [1To lexar ES3 usb SSD](https://www.lexar.com/products/Lexar-ES3-Portable-SSD/)
- 1 [80mm fan](https://www.thermalright.com/product/tl-8015w/)
- 3 very short cat6 ethernet cables
- a [3d printed rack](https://github.com/k0rventen/lampone/tree/main/resources/3d)
- some m3 threaded inserts and screws

The rack is a remix of [this one](https://makerworld.com/en/models/180806-raspberry-pi-4-5-mini-server-rack-case). I've included the stls that I remixed/designed, aka the vented sleds for the PI4 and the SSD, and the side fan mount.


## Software

Here is a top view diagram of the main components:

![architecture](./resources/arch.png)

This is the repo that governs almost all the cluster. The bootstrapping is done using ansible, from 3 ssh-available machines (pi4 in this case).

From here, Flux will create everything that is declared in `k8s/`, decrypt what's secret using a private key, and keep the stack in sync.

In `k8s/` there are 2 main folders:
- `infra` that represents what's needed for the cluster to function:
  - a NFS provisionner as a storageclass,
  - an IngressController with [Traefik](https://github.com/traefik/traefik), one private (listens on local lan), one "public" (routes specific subdomains from cloudflare),
  - [cert-manager](https://github.com/cert-manager/cert-manager) for certificates management of my domain,
  - [cloudflare tunnel](https://github.com/cloudflare/cloudflared) for exposing part of my services to the outside world,
  - [tailscale-operator](https://github.com/tailscale/tailscale/tree/main/cmd/k8s-operator/deploy) for accessing my private services from wherever (using a subnet route) and for my cluster services to access my offsite backup server
  - [system-upgrade-controller](https://github.com/rancher/system-upgrade-controller) for managing k8s upgrades directly in the cluster using CRDs.
  - [renovate](https://github.com/renovatebot/renovate) cronjob to create PR for components updates (w/ auto merging when it's a patch level update)
  - [restic](https://github.com/restic/restic) cronjob that create the local backup (if an app fails and borks its files) and remote backup (if the server catches fire)


- `apps`, the actual services running on the cluster:
  - [adguard](https://github.com/AdguardTeam/AdGuardHome) for DNS/DHCP
  - [gitea](https://github.com/go-gitea/gitea) for local git and CI/CD
  - [paperless-ngx](https://github.com/paperless-ngx/paperless-ngx) for my important files
  - [immich](https://github.com/immich-app/immich) for photos backups and sync
  - [vaultwarden](https://github.com/dani-garcia/vaultwarden) as my passwords manager
  - [filebrowser](https://github.com/gtsteffaniak/filebrowser) for file sharing
  - [glance](https://github.com/glanceapp/glance) as my internet homepage
  - [kromgo](https://github.com/kashalls/kromgo) for exposing prom stats publicly
  - [octoprint](https://github.com/OctoPrint/OctoPrint) for controlling my 3D printer
  - [pocketid](https://github.com/pocket-id/pocket-id) as an OIDC provider
  - [atuin](https://github.com/atuinsh/atuin) for my centralized shell history
  - [grafana](https://github.com/grafana/grafana) + [prometheus](https://github.com/prometheus/prometheus) + [loki](https://github.com/grafana/loki) for monitoring
  - and some other stuff like a blog , static sites, etc..

- there is also an `appchart` folder. It's a Helm chart that ease the deployment of simple services.



## deployment

I try to adhere to gitops/automation principles.
Some things aren't automated but it's mainly toil (one-time-things during setup).
95% of the infrastructure should be deployable by following these instructions (assuming data and encryption keys are known).

Requirements and basic stack:
- [ansible](https://docs.ansible.com/): infrastructure automation
- [flux](https://fluxcd.io/flux/): cluster state mgmt
- [sops](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age/): encryption
- [git](https://git-scm.com/): change management

```
brew install git ansible fluxcd/tap/flux sops age
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


### Creating the cluster

It is assumed that a ssh key auth is configured on the nodes (ssh-copy-id <ip>),
with passwordless sudo (`<user> ALL=(ALL) NOPASSWD: ALL` in visudo).

```
cd ansible
ansible-playbook -i inventory.yaml -l lampone cluster-install.yaml
```


## Deploying the stack

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

3. Things should start to deploy ! :magic:


## backup strategy

I try to follow a 3-2-1 backup rule. The 'live' data is on the nfs ssd.
It's backed up daily onto the same ssd (mainly for rollbacks and potential local re-deployments).
For disaster-recovery situations, it's also backed up daily onto a HDD offsite, which can be accessed through my tailnet.

The backup tool is [restic](https://restic.net/) . It's deployed as a cronjob in the cluster. The image used runs a custom script that runs both the local restic backup as well as the remote one (which requires commands before and after to mount the external disk.). Here are the commands used to create the restic repos before deploying the cronjob:

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


<details>
<summary><h3> Staging / tests env (WIP)</h3></summary>

A staging environment can be deployed using [vagrant](https://developer.hashicorp.com/vagrant/downloads):
```
brew tap hashicorp/tap
brew install hashicorp/tap/vagrant
sudo apt install virtualbox vagrant --no-install-recommends
```

Then create the staging env:
```sh
# launch
vagrant up

# add the nodes ssh config
vagrant ssh-config >> $HOME/.ssh/config

# deploy the cluster
cd ansible
ansible-playbook -i inventory.yaml -l staging cluster-install.yaml

# get the kubectl config
cd ..
vagrant ssh -c "kubectl config view --raw" staging-master > $HOME/.kube/configs/staging

# test
kubectl get nodes
```

Then bootstrap the cluster using flux from [this section](#deploying-the-services), ideally using a develop branch.

</details>
