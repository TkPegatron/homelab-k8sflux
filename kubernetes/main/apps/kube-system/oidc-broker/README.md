# OIDC-via-Vault broker for Kubernetes access

An alternative to `auth-oidc-apiserver` (direct kube-apiserver OIDC).
Here, the apiserver does **no** OIDC configuration at all — it only ever
sees normal Kubernetes ServiceAccount tokens. Authentication happens
entirely at OpenBao: a human logs into OpenBao via OIDC, then reads a
short-lived, RBAC-bound Kubernetes token from OpenBao's Kubernetes
secrets engine.

## Why this instead of direct OIDC

The direct-OIDC branch reproduces prod's mechanism — and if FreeLens
already drops tokens against prod, mirroring the same mechanism here
reproduces the same bug, not a fix. That's a
[known Lens/OpenLens/FreeLens issue](https://github.com/lensapp/lens/issues/5976)
in how it handles OIDC refresh tokens / re-invokes the exec credential
plugin.

This design sidesteps that code path entirely. `kubectl`/FreeLens never
holds an OIDC token at all — they hold a plain Kubernetes ServiceAccount
token, refreshed the same boring way every kubectl exec-credential
plugin refreshes anything: client-go notices the token's
`expirationTimestamp` is close, re-runs the plugin, gets a new one. No
refresh_token, no silent-failure-prone OAuth2 dance on the Kubernetes
side of the flow at all — the OIDC part only happens against OpenBao,
and only as often as OpenBao's own (longer-lived, cached) CLI session
expires.

## The trade-off, honestly

This moves complexity rather than removing it. Specifically: OpenBao
now needs its own credential to reach *into* this cluster's TokenRequest
API (to mint tokens for `oidc-broker-admin`/`oidc-broker-viewer`) — the
exact same "static long-lived credential" shape already flagged as a
finding for the *existing* `openbao-reviewer` token in `mod.just`'s
`openbao` recipe (a 10-year token, minted once, never rotated). Left
unaddressed, this would just be a second instance of that problem.

`rotator-cronjob.yaml` exists specifically to not repeat that mistake:
it re-mints `openbao-k8s-broker`'s token every day and pushes it into
OpenBao automatically, authenticating itself to OpenBao via this
cluster's *existing* `auth/kubernetes` method (the same one
external-secrets already uses) rather than holding any static Vault
credential of its own. The only thing that's actually long-lived here
is the CronJob's own RBAC grant (narrowly scoped, via `resourceNames`,
to minting tokens for exactly one ServiceAccount) — not a credential
that can leak or go stale.

## Setup

1. **This cluster** (this branch): `broker-serviceaccounts.yaml` (the
   two RBAC tiers a user actually gets), `bootstrap-serviceaccount.yaml`
   (what OpenBao itself uses to reach in), `rotator-serviceaccount.yaml`
   + `rotator-cronjob.yaml` (keeps that credential fresh automatically).
2. **OpenBao** (external, run once): `just k8s main openbao-broker`,
   with `OIDC_ISSUER_URL` / `OIDC_CLIENT_ID` / `OIDC_CLIENT_SECRET` set
   in your shell first — see the recipe in `../../../mod.just` for
   exactly what it configures (kubernetes secrets engine, OIDC auth
   method, the rotator's own narrowly-scoped policy).
3. **Map real OIDC groups to the two ACL policies** the recipe creates
   (`k8s-broker-admin`, `k8s-broker-viewer`) via OpenBao's Identity
   system — the recipe creates the policies but does not bind them to
   any group, since it doesn't know your IdP's real group names:
   ```sh
   bao write identity/group name="k8s-admins" policies="k8s-broker-admin" type=external
   bao write identity/group name="k8s-viewers" policies="k8s-broker-viewer" type=external
   # then a group-alias linking each to auth/oidc and the actual IdP group claim value
   ```
4. **Client side**: `.devcontainer/bin/bao-k8s-login` is the
   exec-credential plugin. Kubeconfig:
   ```yaml
   users:
     - name: oidc-broker-admin
       user:
         exec:
           apiVersion: client.authentication.k8s.io/v1
           command: bao-k8s-login
           args: ["admin"]
           interactiveMode: IfAvailable
   ```
   Both `kubectl` and FreeLens read the same kubeconfig format and both
   shell out to the same exec plugin the same way — this isn't
   kubectl-specific.

## Not yet verified against a live cluster

Everything here was written from OpenBao/Vault documentation and one
external write-up, not tested against your actual OpenBao instance:

+ The exact OpenBao HTTP API request/response shapes used in
  `rotator-cronjob.yaml` and `bao-k8s-login` (`auth/kubernetes/login`,
  `k8s-broker/config`, `k8s-broker/creds/<role>`) — confirm field names
  against your installed OpenBao version.
+ Whether `serviceaccounts/token` + `resourceNames` actually scopes a
  `create` verb the way written here (it targets an existing named
  parent object via a subresource, which should support it — this is
  the standard pattern in Vault/OpenBao's own Kubernetes secrets engine
  docs for pinning to a pre-existing ServiceAccount, but worth a direct
  `kubectl auth can-i` check).
+ `alpine/k8s:1.30.4` in the CronJob is an unpinned floating tag — no
  digest was looked up against a registry for this branch; pin one
  before relying on it.

Test the whole loop (`bao login -method=oidc` → `bao-k8s-login admin` →
a real `kubectl get pods` against `kubernetes/testing`/`talos/testing`)
before deciding between this and `auth-oidc-apiserver` for `main`.
