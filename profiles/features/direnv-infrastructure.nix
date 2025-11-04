# Direnv configuration for automatic infrastructure environment
{ config, pkgs, lib, ... }:

{
  # Enhanced direnv configuration
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # Default .envrc template for infrastructure projects
  home.file.".config/direnv/templates/infrastructure.envrc".text = ''
    # Infrastructure project environment
    # This will be automatically used when you have a flake.nix with infrastructure tools

    if has nix; then
      if [[ -f flake.nix ]]; then
        echo "🔧 Loading project-specific tools..."
        use flake
      else
        echo "🔧 Loading basic infrastructure tools..."
        # Basic Nix shell with infrastructure tools
        use nix
      fi
    fi

    # Infrastructure-specific environment variables
    export KUBECONFIG="$HOME/.kube/config"
    export TALOSCONFIG="$HOME/.talos/config"

    # Prompt indicator when in infrastructure environment
    export DIRENV_INFRA=1
  '';

  # Shell integration to show infrastructure environment status
  programs.zsh.initExtra = ''
    # Show infrastructure environment indicator
    if [[ -n "$DIRENV_INFRA" ]]; then
      export PS1_SUFFIX="🏗️  "
    fi
  '';

  # Create a helper script to initialize infrastructure projects
  home.packages = with pkgs; [
    (writeShellScriptBin "init-infra-project" ''
      #!/usr/bin/env bash
      set -euo pipefail

      PROJECT_DIR="''${1:-.}"
      cd "$PROJECT_DIR"

      if [[ ! -f .envrc ]]; then
        echo "🏗️  Initializing infrastructure project environment..."

        # Copy the infrastructure envrc template
        cp ~/.config/direnv/templates/infrastructure.envrc .envrc

        # Allow direnv to use it
        direnv allow

        echo "✅ Infrastructure environment configured!"
        echo "💡 Tools available: kubectl, talosctl, terraform, helm, k9s"
        echo "🔗 Connect to VPN with: sudo tailscale up"
      else
        echo "⚠️  .envrc already exists in this directory"
      fi
    '')
  ];

  # Auto-setup for common infrastructure directories
  home.activation.setupInfraDirectories = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Create Projects directory if it doesn't exist
    mkdir -p ~/Projects

    # Auto-setup infrastructure projects (any directory with flake.nix)
    for project_dir in ~/Projects/*/; do
      if [[ -f "$project_dir/flake.nix" && ! -f "$project_dir/.envrc" ]]; then
        cd "$project_dir"
        ${pkgs.bash}/bin/bash -c "init-infra-project ."
      fi
    done
  '';
}
