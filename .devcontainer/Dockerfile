FROM docker.io/nixos/nix:2.35.2

# - { Configure image to use flakes }
RUN mkdir -p /etc/nix && \
    echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# - { Setup Profile }
# zsh and direnv aren't installed here even though the base image needs a
# working shell/direnv eventually — the home-manager activation below
# provides both (programs.zsh.enable, programs.direnv.enable), and installing
# them twice conflicts when that activation tries to merge into this same
# profile. gnused is unrelated to either; VS Code's server preflight needs it
# and nothing else provides it.
RUN nix profile install nixpkgs#gnused

# zsh's direnv hook is wired up by home-manager itself (it manages zsh via
# ZDOTDIR, so ~/.zshrc isn't even the file zsh reads); bash isn't managed by
# home-manager, so it still needs doing by hand here.
RUN echo 'eval "$(direnv hook bash)"' >> /root/.bashrc

# - { Let non-Nix dynamically-linked binaries run (e.g. the VS Code server) }
# This image has no /lib64/ld-linux-x86-64.so.2, which any prebuilt FHS binary
# (like VS Code's server, downloaded and exec'd by the Dev Containers
# extension) expects as its ELF interpreter. nix-ld provides a stand-in loader
# at that path which reads NIX_LD/NIX_LD_LIBRARY_PATH to find the real linker
# and shared libraries at runtime.
RUN nix profile install "nixpkgs#glibc^out" nixpkgs#stdenv.cc.cc.lib nixpkgs#nix-ld && \
    mkdir -p /lib64 && \
    ln -sf /root/.nix-profile/bin/nix-ld /lib64/ld-linux-x86-64.so.2
ENV NIX_LD=/root/.nix-profile/lib/ld-linux-x86-64.so.2
ENV NIX_LD_LIBRARY_PATH=/root/.nix-profile/lib

# The VS Code server's own preflight (check-requirements.sh) looks for glibc
# via ldconfig / well-known FHS paths, neither of which exist here — but it
# explicitly skips that check when /etc/os-release reports ID=nixos.
RUN printf 'ID=nixos\nNAME=Nix\n' > /etc/os-release

# - { Apply the home-manager config (shell, prompt, git identity, gpg) }
# Container-only path for hosts with no Nix — on NixOS, don't use this image;
# `nix develop`/direnv into this repo's devShell atop your own system/home
# config instead (see flake.nix). Built from a copy of just flake.{nix,lock}
# since the real bind-mounted /workspace isn't present at image build time;
# it takes over identically once the workspace is actually mounted.
COPY flake.nix flake.lock /root/.hm-src/
RUN cd /root/.hm-src && \
    nix build ".#homeConfigurations.container.activationPackage" -o /root/.hm-result && \
    nix profile remove git-minimal && \
    HOME=/root USER=root /root/.hm-result/activate && \
    rm -rf /root/.hm-src /root/.hm-result

WORKDIR /workspace
