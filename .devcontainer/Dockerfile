FROM docker.io/nixos/nix:2.35.2

# - { Configure image to use flakes }
RUN mkdir -p /etc/nix && \
    echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# - { Setup Profile }
RUN nix profile install nixpkgs#zsh nixpkgs#direnv

RUN echo 'eval "$(direnv hook zsh)"' >> /root/.zshrc && \
    echo 'eval "$(direnv hook bash)"' >> /root/.bashrc

WORKDIR /workspace
