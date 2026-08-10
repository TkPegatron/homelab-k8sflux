# Direct kube-apiserver OIDC authentication

Replicates the same mechanism as prod: the apiserver validates OIDC ID
tokens directly (`--oidc-*` flags), no broker in between.

## What's configured where

+ `talos/main/machineconfig.yaml.j2` — `cluster.apiServer.extraArgs` now
  carries `oidc-issuer-url`, `oidc-client-id`, `oidc-username-claim`,
  `oidc-username-prefix`, `oidc-groups-claim`, `oidc-groups-prefix`. Fill
  in the real issuer URL and client ID (matching whatever's registered
  in prod) before applying — the values committed here are placeholders.
+ `app/clusterrolebinding-example.yaml` — two `ClusterRoleBinding`s to
  `kind: Group`, same pattern already used for `flux-web-admin`
  (`../../flux-system/operator/app/clusterrolebinding.yaml`). The group
  name Kubernetes sees is the token's group claim *with the
  `oidc-groups-prefix` prepended* — if your IdP group is `k8s-admins`
  and the prefix is `oidc:`, bind to `oidc:k8s-admins`, not the bare
  name. Replace the placeholder group names before this does anything
  real; as committed, it's inert (no real token will ever carry a group
  literally spelled `oidc:k8s-admins`).

## What this doesn't need

No client secret touches the apiserver config. OIDC token validation is
signature-based (the apiserver fetches the issuer's JWKS via its
discovery document and checks the JWT signature + `aud` claim) — the
OAuth2 authorization-code exchange, where a client secret would matter,
happens entirely on the client side, inside whatever kubectl exec plugin
does the browser login (`kubelogin` / `oidc-login`).

## Client side (kubeconfig)

```yaml
users:
  - name: oidc
    user:
      exec:
        apiVersion: client.authentication.k8s.io/v1
        command: kubectl
        args:
          - oidc-login
          - get-token
          - --oidc-issuer-url=https://your-idp.example
          - --oidc-client-id=kubernetes
          - --oidc-extra-scope=groups
          - --oidc-extra-scope=email
```

## The FreeLens problem this doesn't fix

If prod already uses this exact mechanism and FreeLens still drops out
there, mirroring the same mechanism here reproduces the same problem,
not a fix for it. This is a
[known, long-standing issue](https://github.com/lensapp/lens/issues/5976)
in Lens/OpenLens/FreeLens: it doesn't reliably re-invoke the exec
credential plugin (or mishandles the cached refresh token) the way
kubectl does. Nothing on the apiserver or IdP side changes that — it's
a client bug. See the sibling branch `auth-oidc-vault-broker` for an
approach that sidesteps it entirely by not relying on OIDC token
refresh at all for the Kubernetes-facing credential.
