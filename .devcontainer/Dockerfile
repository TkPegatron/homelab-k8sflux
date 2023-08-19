ARG VARIANT=3.18
FROM docker.io/library/alpine:${VARIANT}

# -{ ENV: Consume Environment variables }
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG TZ=America/Detroit

# -{ MOD: Add repositories }
RUN /bin/true \
    && echo "https://dl-cdn.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories

# -{ PMINST: Important system utilities }
RUN apk add --upgrade --no-cache \
    util-linux pciutils usbutils coreutils binutils findutils grep iproute2

RUN apk add --upgrade --no-cache dog

RUN apk add --upgrade \
    zsh bat direnv curl exa stow file git skim neovim starship tzdata \
    ca-certificates gpg gpg-agent openssh-client libcrypto3 \
    python3 py3-pip sshpass pcre rsync

# Environment tools (For Terraform, Kubernetes & Ansible GitOps workflow)
RUN apk add --upgrade --no-cache \
    kubectl kustomize helm ansible terraform age pre-commit jq yq \
    yamllint ansible-lint ipcalc sops flux ceph17-mgr-dashboard

# Install go-task
RUN sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin

# -{ MOD: Configure userspace environment }

RUN \
    # Set the container's timezone \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone; \
    # Add local user account inside container \
    adduser --shell /bin/zsh --disabled-password $USERNAME

USER $USERNAME

# Install Python Dependencies
COPY ./requirements.txt /opt/requirements.txt
RUN pip install -r /opt/requirements.txt --break-system-packages

# Install Ansible Depenedencies
COPY ./requirements.yml /opt/requirements.yml
RUN ansible-galaxy install -r /opt/requirements.yml