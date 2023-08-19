# Snippets

Sippets incase something changes down the line and the following need to be reinstalled using their source URLs.


```dockerfile
# Install Mozilla SOPS
RUN wget --output-document="/tmp/sops" "https://github.com/mozilla/sops/releases/download/v3.7.3/sops-v3.7.3.linux.amd64" \
    && chmod +x /tmp/sops && mv /tmp/sops /usr/local/bin/sops

# Install go-task
RUN sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin

# Install (kubernetes-sigs) kustomize
RUN curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash

# Install fluxcd
RUN curl -s "https://fluxcd.io/install.sh" | bash
```