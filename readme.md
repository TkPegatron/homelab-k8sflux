<div align="center">

<img src="https://camo.githubusercontent.com/5b298bf6b0596795602bd771c5bddbb963e83e0f/68747470733a2f2f692e696d6775722e636f6d2f7031527a586a512e706e67" align="center" width="144px" height="144px"/>

### My Kubernetes homelab repository :octocat:

_... managed with Flux, Renovate and GitHub Actions_ 🤖

</div>

---

## 📖 Overview

This repository contains kubernetes manifests the ansible provisioning playbooks for my homelab's k8s cluster.

## ⛵ Kubernetes

There is a template over at [onedr0p/flux-cluster-template](https://github.com/onedr0p/flux-cluster-template) if you wanted to try and follow along with some of the practices I use here.

### Installation

My cluster is [k3s](https://k3s.io/) provisioned overtop bare-metal Rocky Linux using the [Ansible](https://www.ansible.com/) galaxy role [ansible-role-k3s](https://github.com/PyratLabs/ansible-role-k3s). This is a semi hyper-converged cluster, workloads and block storage are sharing the same available resources on my nodes while I have a separate server for long-term, backup, and volume file storage (NFS & S3).

### Core Components

- [cert-manager](https://cert-manager.io/docs/): manages certificates, like certbot but as a k8s operator and api extensions.
- [external-dns](https://github.com/kubernetes-sigs/external-dns): synchronizes DNS records from my cluster ingresses to a DNS provider.
- [ingress-nginx](https://github.com/kubernetes/ingress-nginx/): ingress controller for Kubernetes using NGINX as a reverse proxy and load balancer.
- [rook](https://github.com/rook/rook): distributed block storage.
- [sops](https://toolkit.fluxcd.io/guides/mozilla-sops/): Secrets encryption mechanism for Kubernetes secrets (among other uses).

### GitOps

[Flux](https://github.com/fluxcd/flux2) watches my [kubernetes](./kubernetes/) folder (see Directories below) and makes the changes to my cluster based on the YAML manifests.

[Renovate](https://github.com/renovatebot/renovate) watches my **entire** repository looking for dependency updates, when they are found a PR is automatically created. When some PRs are merged [Flux](https://github.com/fluxcd/flux2) applies the changes to my cluster.


### Directories

This Git repository contains the following directories under [kubernetes](./kubernetes/).

```sh
📁 kubernetes      # Kubernetes cluster defined as code
├─📁 bootstrap     # Flux installation
├─📁 flux-config   # Main Flux configuration repository
├─📁 operators     # Kubernetes Operators, Controllers, and Plugins grouped by namespace
└─📁 applications  # Apps deployed into my cluster grouped by namespace
```

---

## 🤝 Gratitude and Thanks

Thanks to all the people who donate their time to the [Kubernetes @Home](https://discord.gg/k8s-at-home) Discord community. A lot of inspiration for my cluster comes from the people that have shared their clusters using the [k8s-at-home](https://github.com/topics/k8s-at-home) GitHub topic. Be sure to check out the [Kubernetes @Home search](https://nanne.dev/k8s-at-home-search/) for ideas on how to deploy applications or get ideas on what you can deploy.

---

## 🔏 License

See [LICENSE](./LICENSE)
