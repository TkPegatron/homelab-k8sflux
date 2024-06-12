FROM ghcr.io/tkpegatron/opsdev:rolling

# -{ ENV: Consume VSCode Environment variables }
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG TZ=America/Detroit

# -{ MOD: Configure userspace environment }
RUN \
    # Set the container's timezone \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone; \
    # Add local user account inside container \
    adduser --shell /bin/zsh --disabled-password $USERNAME

# Install Krew and Krew Accessories
run set -x; cd "$(mktemp -d)" && \
    OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
    KREW="krew-${OS}_${ARCH}" && \
    curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" && \
    tar zxvf "${KREW}.tar.gz" && \
    mv ./"${KREW}" /usr/bin/kubectl-krew

USER $USERNAME


ENV PATH="$PATH:/home/$USERNAME/.local/bin"

# Install Python Dependencies
COPY ./requirements.txt /opt/requirements.txt
RUN pip install -r /opt/requirements.txt --break-system-packages

# Install Ansible Depenedencies
COPY ./requirements.yml /opt/requirements.yml
RUN ansible-galaxy install -r /opt/requirements.yml
