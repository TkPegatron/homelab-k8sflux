{
  description = "homelab-k8sflux development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    dotfiles.url = "github:lunapageofspace/NixOS";
  };

  outputs = { self, nixpkgs, flake-utils, dotfiles }:
    (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        # Override the default kubernetes-helm to use version 4.2.0
        k8shelm = pkgs.buildGoModule rec {
          pname = "kubernetes-helm";
          version = "4.2.0";
          src = pkgs.fetchFromGitHub {
            owner = "helm";
            repo = "helm";
            rev = "v${version}";
            #sha256 = pkgs.lib.fakeHash;
            sha256 = "sha256-Wyihzf7KpnVuIdp5lmjhB7uLAGgtmI0TXYl29uaVC5Y=";
          };
          doCheck = false;
          #vendorHash = pkgs.lib.fakeHash;
          vendorHash = "sha256-QTDC0v0BPE3FoK9AAq1n2jWxOE9gB9OsoY2wnpcCDUQ=";
          subPackages = [ "cmd/helm" ];
          meta = with pkgs.lib; {
            description = "The Kubernetes Package Manager";
            homepage = "https://helm.sh/";
            license = licenses.asl20;
            maintainers = with maintainers; [ ];  # optional
          };
        };
      in {
        devShells.default = pkgs.mkShell {
          name = "kubernetes-shell";

          buildInputs = with pkgs; [
            bitwarden-cli
            minijinja
            kustomize
            helmfile
            talosctl
            cilium-cli
            helm-ls
            just-lsp
            fluxcd
            k8shelm
            sops
            openbao
            k9s
            just
            vals
            gum
            jq
            yq-go
          ] ++ [
            kubectl
            kubescape
            kubectl-cnpg
            kubectl-graph
            kubelogin-oidc
          ];

          shellHook = ''
            export TZ="America/Detroit"
            export TZDIR="${pkgs.tzdata}/share/zoneinfo"
            echo "Ready!"
          '';
        };

      }
    )) // {
      # Built and activated inside the devcontainer image (see
      # .devcontainer/Dockerfile) for hosts with no Nix installed. On a
      # NixOS host, don't use this — that system's own home-manager module
      # already applies; just `nix develop`/direnv into this repo's devShell
      # atop it instead.
      homeConfigurations.container = dotfiles.homeConfigurations.elliana-shell;
    };
}