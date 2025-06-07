# Infrastructure-focused development shell
# Can be used by any infrastructure repository
{ pkgs, lib, ... }:

let
  infraTools = import ../packages/infrastructure-tools.nix { inherit pkgs lib; };
in {
  devShells = {
    # Core infrastructure shell
    infrastructure = pkgs.mkShell {
      name = "infrastructure-development";
      
      packages = infraTools.infrastructureTools;
      
      shellHook = ''
        echo "🏗️  Infrastructure Development Environment"
        echo "📦 Tools: $(echo ${builtins.toString infraTools.infrastructureTools} | wc -w) packages loaded"
        echo "🔧 kubectl, terraform, helm, k9s, and more available"
        
        # Set common infrastructure environment
        export KUBECONFIG="$HOME/.kube/config"
        export TALOSCONFIG="$HOME/.talos/config"
        
        # Helpful aliases
        alias k="kubectl"
        alias kx="kubectx"
        alias tf="terraform"
        alias tg="terragrunt"
      '';
    };

    # Kubernetes-focused shell
    kubernetes = pkgs.mkShell {
      name = "kubernetes-development";
      
      packages = infraTools.kubernetesTools ++ [
        pkgs.stern  # Log streaming
        pkgs.dive   # Container image analysis
      ];
      
      shellHook = ''
        echo "☸️  Kubernetes Development Environment"
        echo "🔧 kubectl, helm, k9s, stern available"
        
        export KUBECONFIG="$HOME/.kube/config"
        alias k="kubectl"
        alias kx="kubectx"
      '';
    };

    # Security-focused shell
    security = pkgs.mkShell {
      name = "security-development";
      
      packages = infraTools.securityTools ++ [
        pkgs.nmap
        pkgs.openssl
      ];
      
      shellHook = ''
        echo "🔒 Security Development Environment"
        echo "🔧 sops, age, step-cli, vault available"
      '';
    };
  };
}