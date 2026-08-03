# VolSync component

Kustomize component providing per-app PVC + backup (`ReplicationSource`)
+ restore (`ReplicationDestination`) wiring via `${APP}` substitution.
Included by an app's `ks.yaml` like jellyfin's:

```yaml
spec:
  components:
    - ../../../../components/volsync
  postBuild:
    substitute:
      APP: jellyfin
      APP_NAMESPACE: media
      VOLSYNC_CAPACITY: 5Gi
```

## The bootstrap race this solves

`ReplicationDestination`'s restore Job needs to be the only thing bound
to the PVC. During a normal Flux reconcile, the app's Deployment and the
restore Job both get created around the same time — nothing stops the
Deployment's pod from binding the PVC first, before the restore Job gets
a chance to run.

`mutatingadmissionpolicybinding.yaml` opts `${APP}`'s Deployment into
`../../apps/volsync-system/volsync/app/hold-until-restored-policy.yaml`,
a native `MutatingAdmissionPolicy` (CEL, no extra controller — same
mechanism as `../../apps/kube-system/pod-admission-policy/`). It forces
`spec.replicas: 0` on `${APP}`'s Deployment for as long as `${APP}-dst`
(the `ReplicationDestination` this component also creates) has a manual
restore trigger set that hasn't completed yet.

This works the same way whether there's real data to restore or not,
because it keys off VolSync's own trigger/completion fields
(`spec.trigger.manual` vs `status.lastManualSync`), not "is there a
backup" — `replicationdestination.yaml` always sets
`trigger.manual: restore-once`:

- **Fresh bootstrap, empty repository**: the restore Job runs once,
  finds nothing to restore, completes, `status.lastManualSync` becomes
  `"restore-once"` — the hold releases as soon as that Job finishes.
- **Restoring real data** (e.g. after a full cluster rebuild): same
  mechanism, the Job actually has something to copy first.

Either way, the Deployment never gets a chance to bind the PVC before
the restore Job has run to completion at least once.

## Wiring a new app into this

1. Include the component and set `APP` + `APP_NAMESPACE` in
   `postBuild.substitute` (both are required — `APP_NAMESPACE` is new;
   it's needed because `MutatingAdmissionPolicyBinding` is cluster-scoped
   and can't inherit a namespace from `targetNamespace` the way
   namespaced resources do). Flux's `postBuild.substitute` fails the
   whole `Kustomization` if a variable is missing, so forgetting this
   fails loudly rather than silently misbinding.
2. Nothing else — the Deployment just needs the standard
   `app.kubernetes.io/instance: ${APP}` label Helm already sets on it.

## After a restore actually completes

The hold releases as soon as `${APP}-dst`'s status updates, but Flux
won't necessarily re-apply the Deployment (and pick up its real replica
count) until its next reconcile interval — that could be up to an hour.
Don't wait for it during a bootstrap; force it:

```sh
kubectl wait replicationdestination/${APP}-dst -n ${APP_NAMESPACE} \
  --for=jsonpath='{.status.lastManualSync}'=restore-once --timeout=15m
flux reconcile kustomization ${APP} --with-source
```

## Not yet verified against a live cluster

- Whether `matchConditions` on a `MutatingAdmissionPolicy` can reference
  `params` (used here to read the `ReplicationDestination`'s status) —
  written from the admission API's documented design, not confirmed
  against your exact 1.36 build.
- Whether your installed `kustomize` version's cluster-scoped-resource
  list already includes `MutatingAdmissionPolicyBinding` /
  `ValidatingAdmissionPolicyBinding` — if not, the namespace transformer
  from a Kustomization's `targetNamespace` could incorrectly stamp a
  `metadata.namespace` onto these cluster-scoped objects. Worth a
  `kustomize build` / `kubeconform` check on this component and on
  `../../apps/kube-system/pod-admission-policy/` before relying on either.

Test the whole flow — bootstrap a node against
`kubernetes/testing`/`talos/testing` with a non-empty Kopia repository —
before trusting this during a real `main` rebuild.
