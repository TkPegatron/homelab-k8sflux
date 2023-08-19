# Bootstrap

## Labels

During the creation of the cluster, labels can sometimes be missing from the second and third nodes.

To relabel them, run the following

```sh
for node in {"amd64-server-7f97c6.int.zynthovian.xyz","amd64-server-a2e7bb.int.zynthovian.xyz"}; do
    kubectl label nodes $node node-role.kubernetes.io/etcd=true
    kubectl label nodes $node node-role.kubernetes.io/control-plane=true
    kubectl label nodes $node node-role.kubernetes.io/master=true
done
```

## Flux

### Install Flux

```sh
kubectl apply --server-side --kustomize ./kubernetes/bootstrap/flux
```

### Apply Cluster Configuration

_These cannot be applied with `kubectl` directly due to being encrypted with sops_

```sh
sops --decrypt kubernetes/bootstrap/flux/age-key.sops.yaml | kubectl apply -f -
sops --decrypt kubernetes/bootstrap/flux/git-deploy-key.sops.yaml | kubectl apply -f -
sops --decrypt kubernetes/flux/vars/cluster-secrets.sops.yaml | kubectl apply -f -
kubectl apply -f kubernetes/flux/vars/cluster-settings.yaml
```

### Kick off Flux applying this repository

```sh
kubectl apply --server-side --kustomize ./kubernetes/flux/config
```
