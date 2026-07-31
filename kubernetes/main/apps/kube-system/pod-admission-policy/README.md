# Pod admission policy baseline

Cluster-wide pod hardening enforced via native Kubernetes
`ValidatingAdmissionPolicy` (CEL-based, built into the API server since
1.30 — no extra controller to run or upgrade). This is the same primitive
already in use for `../grafana-operator/instance/mutatingadmissionpolicy.yaml`
(the Grafana Docker Hub → mirror.gcr.io image rewrite), just applied to
enforcement instead of mutation.

## What's in here

- **`require-resource-limits`** — every container must set a memory
  limit. Nothing in this cluster enforced that before; 16 of 21
  workloads had none set when this was written.
- **`restrict-privileged-namespaces`** — `hostNetwork`/`hostPID`/`hostIPC`
  and privileged containers are only admitted in `kube-system`,
  `network`, `longhorn-system`, and `openebs-system` — the same four
  namespaces already labeled `pod-security.kubernetes.io/enforce:
  privileged`. This makes that documented exception structural instead
  of just a label.

## Rollout: audit/warn before deny

Both policies ship with `validationActions: [Audit, Warn]`, not `[Deny]`.
That means right now:

- Nothing is blocked.
- A request that would have failed shows a `kubectl` warning to whoever
  ran it, and an audit log annotation (`validation.policy.admission.k8s.io/...`)
  on the apiserver's audit trail.

This is the same audit-before-enforce pattern used elsewhere in this
repo (Cilium's `policyAuditMode`, the PSA labels' `audit`/`warn` before
`enforce`). Watch for warnings for a while, fix what trips it, *then*
change `validationActions` to `[Deny]` on the `ValidatingAdmissionPolicyBinding`
— that's the only field that needs to change to go from observing to
enforcing.

## Bypassing a policy for a genuine edge case

Sometimes a specific pod really does need an exception — a one-off debug
pod that needs `hostPID`, a workload that can't have a memory limit for a
good reason. Each policy's `matchConditions` skips evaluation entirely
for any pod carrying the matching label:

| Policy | Bypass label |
|---|---|
| `require-resource-limits` | `policy.zynthovian.xyz/exempt-resource-limits: "true"` |
| `restrict-privileged-namespaces` | `policy.zynthovian.xyz/exempt-privileged: "true"` |

The label goes on the **pod template**, not the namespace — so it has to
be added in the HelmRelease/manifest that defines the workload, which
means it's visible in a PR diff and gets reviewed like any other change.
That's deliberate: an exemption should be a decision someone made in
code, not a `kubectl label` run against a live cluster that leaves no
trail.

Two ways to set it, depending on the chart:

**bjw-s common-library charts** (jellyfin, homepage, vpn-gateway) —
under `defaultPodOptions` or a specific controller's `pod`:

```yaml
values:
  defaultPodOptions:
    labels:
      policy.zynthovian.xyz/exempt-resource-limits: "true"
```

**Plain Deployment/DaemonSet-style charts** — under whatever the chart
calls its pod template labels, e.g.:

```yaml
values:
  podLabels:
    policy.zynthovian.xyz/exempt-privileged: "true"
```

Always pair the label with a comment saying *why* — the label alone
doesn't explain itself to the next person reading the diff.

## Adding a new policy

Same shape as the two here: a `ValidatingAdmissionPolicy` +
`ValidatingAdmissionPolicyBinding` pair, `matchConditions` for the bypass
label if one makes sense for that check, `validationActions: [Audit,
Warn]` to start. Add the file to `app/kustomization.yaml`.
