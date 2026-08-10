set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

set export
export cluster := "main"
controller := `talosctl config info -o yaml | yq -e '.endpoints[0]'`
nodes := `talosctl config info -o yaml | yq -e '.nodes | join (" ")'`

[private]
default:
    just -l k8s {{ cluster }}

[confirm('Bootstrap cluster? [y|N]')]
[doc('Bootstrap a Talos & Kubernetes cluster end-to-end')]
bootstrap: nodes k8s (kubeconfig "node") base apps kubeconfig openbao

[private]
[script]
nodes:
    just log info "Running stage..." "stage" "$(basename "$0")"
    for n in {{ nodes }}; do
        if ! op=$(just --yes talos {{ cluster }} apply-node "$n" --insecure 2>&1); then
            if [[ "$op" == *"certificate required"* ]]; then
                just log info "Talos already configured, skipping apply of config" "stage" "$(basename "$0")" "node" "$n"
                continue
            fi
            just log fatal "Failed to apply Talos configuration" "stage" "$(basename "$0")" "node" "$n" "output" "$op"
        fi
    done

[private]
[script]
k8s:
    just log info "Running stage..." "stage" "$(basename "$0")"
    until op=$(talosctl -n "{{ controller }}" bootstrap 2>&1 || true) && [[ "$op" == *"AlreadyExists"* ]]; do
        just log info "Kubernetes bootstrap in progress. Retrying in 5 seconds..." "stage" "$(basename "$0")"
        sleep 5
    done

[private]
[script]
kubeconfig lb="cilium":
    just log info "Running stage..." "stage" "$(basename "$0")"
    if ! talosctl kubeconfig --nodes "{{ controller }}" --merge --force --force-context-name {{ cluster }} {{ justfile_dir() }}; then
        just log fatal "Failed to fetch kubeconfig" "stage" "$(basename "$0")"
    fi
    if [[ "{{ lb }}" != "cilium" ]]; then
        if ! kubectl config set-cluster {{ cluster }} --server "https://{{ controller }}:6443"; then
            just log fatal "Failed to set kubectl cluster server address" "stage" "$(basename "$0")"
        fi
    fi

[private]
[script]
base: ready
    just log info "Running stage..." "stage" "$(basename "$0")"
    if ! kustomize build {{ source_directory() }}/bootstrap/kustomize/apps | just template - | kubectl apply --server-side --force-conflicts -f -; then
        just log fatal "Failed to apply base manifests" "stage" "$(basename "$0")" "file" "$f"
    fi
    if ! helmfile -f "{{ source_directory() }}/bootstrap/helmfile/crds.yaml" template -q | yq -e 'select(.kind == "CustomResourceDefinition")' | kubectl apply --server-side --force-conflicts -f -; then
        just log fatal "Failed to apply base crds" "stage" "$(basename "$0")"
    fi

[private]
[script]
apps:
    just log info "Running stage..." "stage" "$(basename "$0")"
    if ! helmfile -f "{{ source_directory() }}/bootstrap/helmfile/apps.yaml" sync --hide-notes; then
        just log fatal "Failed to sync helmfile" "stage" "$(basename "$0")"
    fi

# Wait until nodes register as Ready=False. They only become Ready=True once the CNI is healthy.
[private]
[script]
ready:
    just log info "Running stage..." "stage" "$(basename "$0")"
    if ! kubectl wait nodes --for=condition=Ready=True --all --timeout=10s &>/dev/null; then
        until kubectl wait nodes --for=condition=Ready=False --all --timeout=10s &>/dev/null; do
            just log info "Nodes not available, waiting for nodes to be available. Retrying in 5 seconds..." "stage" "$(basename "$0")"
            sleep 5
        done
    fi

# Flux Recipes
[group: 'Flux']
[script]
sync-all:
    kubectl get gitrepositories --all-namespaces --no-headers | awk '{print $1, $2}' \
        | xargs --max-procs=4 -l bash -c \
            'flux reconcile source git $1 -n $0'
    kubectl get kustomization --all-namespaces --no-headers | awk '{print $1, $2}' \
        | xargs --max-procs=4 -l bash -c \
            'kubectl -n $0 annotate kustomization/$1 reconcile.fluxcd.io/requestedAt="$(date +%s)" --field-manager=flux-client-side-apply --overwrite'

[doc('Configure OpenBAO for Kubernetes authentication')]
[script]
openbao:
    just log info "Running stage..." "stage" "$(basename "$0")"

    TOKEN="$(kubectl create token openbao-reviewer -n external-secrets --duration=87600h)"
    CA_CERT="$(talosctl cat /etc/kubernetes/pki/ca.crt)"

    if ! bao write auth/kubernetes/config \
        kubernetes_host="https://k8s.zynthovian.xyz:6443" \
        kubernetes_ca_cert=@<(echo "$CA_CERT") \
        token_reviewer_jwt=@<(echo "$TOKEN"); then
        just log fatal "Failed to write OpenBAO Kubernetes auth config" "stage" "$(basename "$0")"
    fi

[doc('One-time bootstrap of the OIDC-to-Vault-broker auth path (see kube-system/oidc-broker/README.md). Rerunning is safe/idempotent; the daily CronJob keeps the service_account_jwt fresh afterward — this only needs to run once, or again if the OIDC client secret rotates.')]
[script]
openbao-broker:
    just log info "Running stage..." "stage" "$(basename "$0")"

    : "${OIDC_ISSUER_URL:?Set OIDC_ISSUER_URL to your IdP's discovery URL}"
    : "${OIDC_CLIENT_ID:?Set OIDC_CLIENT_ID to the client registered for OpenBao}"
    : "${OIDC_CLIENT_SECRET:?Set OIDC_CLIENT_SECRET — do not commit this anywhere}"

    TOKEN="$(kubectl create token openbao-k8s-broker -n kube-system --duration=48h)"
    CA_CERT="$(talosctl cat /etc/kubernetes/pki/ca.crt)"

    # Kubernetes secrets engine — mints short-lived K8s ServiceAccount
    # tokens on demand, mounted at a distinct path from the kubernetes
    # *auth* method above so the two don't get confused in docs/logs.
    if ! bao secrets list -format=json | jq -e 'has("k8s-broker/")' >/dev/null; then
        bao secrets enable -path=k8s-broker kubernetes
    fi
    bao write k8s-broker/config \
        kubernetes_host="https://k8s.zynthovian.xyz:6443" \
        kubernetes_ca_cert=@<(echo "$CA_CERT") \
        service_account_jwt=@<(echo "$TOKEN")
    bao write k8s-broker/roles/admin \
        allowed_kubernetes_namespaces="kube-system" \
        service_account_name="oidc-broker-admin" \
        token_default_ttl="15m" \
        token_max_ttl="30m"
    bao write k8s-broker/roles/viewer \
        allowed_kubernetes_namespaces="kube-system" \
        service_account_name="oidc-broker-viewer" \
        token_default_ttl="15m" \
        token_max_ttl="30m"

    # OIDC auth method — how a human proves who they are to OpenBao itself,
    # before OpenBao decides whether to hand them a k8s-broker credential.
    if ! bao auth list -format=json | jq -e 'has("oidc/")' >/dev/null; then
        bao auth enable oidc
    fi
    bao write auth/oidc/config \
        oidc_discovery_url="$OIDC_ISSUER_URL" \
        oidc_client_id="$OIDC_CLIENT_ID" \
        oidc_client_secret="$OIDC_CLIENT_SECRET" \
        default_role="k8s-broker-login"
    bao write auth/oidc/role/k8s-broker-login \
        bound_audiences="$OIDC_CLIENT_ID" \
        allowed_redirect_uris="http://localhost:8250/oidc/callback" \
        user_claim="email" \
        groups_claim="groups" \
        policies="default"

    # Rotator's own path to OpenBao: authenticates via this cluster's
    # existing auth/kubernetes method (same one external-secrets uses),
    # scoped to only updating k8s-broker/config.
    # (printf, not a heredoc — heredoc terminators are indentation-sensitive
    # in ways that don't mix well with `just`'s own recipe-body indentation.)
    printf 'path "k8s-broker/config" {\n  capabilities = ["create", "update"]\n}\n' \
        | bao policy write k8s-broker-rotator -
    bao write auth/kubernetes/role/k8s-broker-rotator \
        bound_service_account_names="openbao-token-rotator" \
        bound_service_account_namespaces="kube-system" \
        policies="k8s-broker-rotator" \
        ttl="15m"

    # ACL policies gating who can read which broker role — bind these to
    # real OIDC groups via `bao write identity/group ...` separately;
    # placeholders here don't grant anything until that mapping exists.
    printf 'path "k8s-broker/creds/admin" {\n  capabilities = ["read"]\n}\n' \
        | bao policy write k8s-broker-admin -
    printf 'path "k8s-broker/creds/viewer" {\n  capabilities = ["read"]\n}\n' \
        | bao policy write k8s-broker-viewer -
