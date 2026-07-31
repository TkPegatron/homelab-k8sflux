# Supply chain verification

Two independent layers, added together because they cover different
risks:

## 1. Digest pinning (`require-digest-pinned-images.yaml`) — works today

A native `ValidatingAdmissionPolicy`, no new controller, same mechanism as
`../kube-system/pod-admission-policy/` (if that branch has landed) —
denies (currently: warns about) any pod referencing a container image by
a mutable tag instead of a `@sha256:` digest. Most images in this repo
are already digest-pinned via Renovate; this makes sure that stays true
and catches regressions immediately, cluster-wide, with nothing new to
install.

## 2. Signature verification (Sigstore Policy Controller) — needs setup

Cryptographic signature verification can't be done in pure CEL (it
requires calling out to a transparency log and doing real crypto,
which `ValidatingAdmissionPolicy` deliberately can't do). This installs
[Sigstore's Policy Controller](https://docs.sigstore.dev/policy-controller/overview/),
a purpose-built admission webhook for exactly this, configured
**globally permissive** (`no-match-policy: warn` in
`configmap-warn-mode.yaml`) — installing it does nothing to existing
workloads by itself. `ClusterImagePolicy` objects are what actually
turn on verification, and only for images matching their `images` glob.

`clusterimagepolicy-example.yaml` is a **template, not a working
policy** — it targets `ghcr.io/tkpegatron/*` (your own images) rather
than upstream ones, because that's the part of the supply chain you can
actually make signed today:

1. Most upstream images already in this cluster (jellyfin, envoyproxy,
   coredns, cilium, etc.) aren't cosign-signed by their publishers —
   pointing a policy at them would just fail everything until/unless
   that changes upstream. Not attempted here.
2. Your own images are a different story: add a `cosign sign` step
   (keyless, via GitHub Actions' own OIDC token — no key management)
   to whatever workflow builds/pushes `ghcr.io/tkpegatron/*`, then fill
   in the real repo/workflow path in the example's `subjectRegExp`
   (the placeholder there won't match anything real).
3. Expand to more `images` globs over time as more of what you run
   gets signed.

## Not yet verified against a live cluster

This whole branch was written from documentation research, not tested
against a running cluster:

- The `policy-controller` chart version and the `config-policy-controller`
  ConfigMap's exact name/keys — confirm both once installed
  (`kubectl -n supply-chain get cm config-policy-controller -o yaml`).
- Whether `ClusterImagePolicy` is namespaced or cluster-scoped, and the
  exact `apiVersion`, in whatever policy-controller version actually
  installs.

Test on `kubernetes/testing` before `main`.
