# lampone

My self hosted cloud.



<div align="center">

![cluster uptime](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fcluster_uptime_days&style=for-the-badge&color=blue)
![cluster cpu](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fcluster_cpu_usage&style=for-the-badge)
![cluster ram](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fcluster_memory_usage&style=for-the-badge)
![cluster temp](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fcluster_temperature&style=for-the-badge)
![cluster version](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.cocointhe.cloud%2Fkubernetes_version&style=for-the-badge&color=blue)

</div>

<details>
<summary>Hardware specs</summary>
![cluster image](./3d/cluster.png)

Hardware:
- 3 raspberry pi 4 (8Go)
- 1 gigabit ethernet tp link 5 ports switch
- some m3 threaded inserts and screws
- 1 1To lexar usb SSD
- 1 3d printed rack
- 1 [80mm fan](https://www.thermalright.com/product/tl-8015w/)


The 3d files are available in `3d`. This is a remix of [this rack](https://makerworld.com/en/models/180806-raspberry-pi-4-5-mini-server-rack-case). I've included the stls that I remixed/designed, aka the vented sleds for the PI and the SSD, and the side fan mount.

![files](./3d/files.png)

</details>


<details>
<summary>Software details and architecture</summary>
![architecture](./architecture.png)
</details>


## deployment

I try to adhere to gitops/automation principles.
Some things aren't automated but it's mainly toil (for now).
95% of the infrastructure should be deployable by following these instructions (assuming data and encryption keys are known).

Requirements:
- ansible-playbook
- flux
- sops + age
- git

```
brew install git ansible fluxcd/tap/flux sops age
```


### Creating the cluster

It is assumed that a ssh key auth is configured on the nodes (ssh-copy-id <ip>),
with passwordless sudo (`<user> ALL=(ALL) NOPASSWD: ALL` in visudo).

```
cd ansible
ansible-playbook -i inventory.yaml cluster-install.yaml
```


## Deploying the services
1. Bootstrap flux:

```
export GITHUB_TOKEN=xxx
flux bootstrap github \
              --owner=k0rventen \
              --repository=lampone \
              --branch=main \
              --path=./k8s/flux
```

2. Add the sops age private key to the cluster:

```
kubectl create secret generic sops-age --namespace=flux-system --from-file=age.agekey
```

3. Things should start to deploy

## k3s update

To update the cluster, set the `k3s_version` in the ansible inventory, then:
```
ansible-playbook -i inventory.yaml cluster-update.yaml
```
Check the version of each node using `k get nodes`.

## backup strategy

I try to follow a 3-2-1 backup rule. The 'live' data is on the nfs ssd.
It's backed up daily onto the same ssd (mainly for rollbacks and potential local re-deployments).
For disaster-recovery situations, it's also backed up daily onto a HDD offsite, which can be accessed through my tailnet.

The backup tool is restic. It's installed onto the nfs server.

1. Init the local repo

```
cd /nfs
restic init nfs-backups
```

2. Init the remote repo (this requires a mnt-backup.mount service on the remote server to mount/umount the backup disk, see `restic_files/restic-offsite.service`)
```
restic init -r sftp:100.110.187.29:/mnt/backup/nfs-backups
```

3. Create a systemd cred with the repo password (on the nfs server) and set the value of `restic_systemd_creds` in the ansible inventory:
```
> systemd-ask-password -n | sudo systemd-creds encrypt --name=restic -p - -
🔐 Password: *************************
SetCredentialEncrypted=restic: \
        ...
```

4. Deploy the restic config using ansible:

```
ansible-playbook -i inventory restic-install.yaml
```

## Staging / tests env

A staging environment can be deployed using vagrant:

Prerequisites:
```

sudo apt install
```

Then in `staging/`
```
# launch
vagrant up

# add the nodes ssh config
vagrant ssh-config > .ssh/config

# get the kubectl config
vagrant ssh -c "kubectl config view --raw" staging-master > .kube/configs/staging

# test
kubectl get no
```

Then bootstrap the cluster using flux from []()
