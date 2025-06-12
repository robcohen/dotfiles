{ config, pkgs, lib, inputs, ... }:

let
  # Simple hostname detection with fallback
  detectedHostname = "brix";  # Hardcode for now to avoid infinite recursion
  
  unstable = import inputs.unstable-nixpkgs {
    system = pkgs.system;
    config.allowUnfree = true;
  };
in {
  imports = [
    ./host-specific.nix
    ./packages.nix
    ./session-variables.nix
    ./mimeapps.nix
    ./programs/direnv.nix
    ./programs/gpg.nix
    ./programs/tmux.nix
    ./programs/bash.nix
    ./programs/alacritty.nix
    ./programs/ungoogled-chromium.nix
    ./programs/git.nix
    ./programs/zsh.nix
    ./programs/npm.nix
    ./programs/home-manager.nix
    ./programs/starship.nix
    ./programs/fzf.nix
    ./programs/eza.nix
    ./programs/bat.nix
    ./programs/ripgrep.nix
    ./programs/dircolors.nix
    ./programs/htop.nix
    ./programs/less.nix
    ./programs/ssh.nix
    ./programs/readline.nix
    ./programs/zoxide.nix
    ./programs/atuin.nix
    ./services/gpg-agent.nix
    ./services/syncthing.nix
    ./services/desktop-notifications.nix
    ./services/system-monitoring.nix
    # Security modules (import after base configurations)
    ./security/default.nix
  ];

  nixpkgs = {
    overlays = [ ];
    config = {
      allowUnfree = true;
      allowUnfreePredicate = _: true;
    };
  };

  # Pass config to other modules  
  _module.args = {
    hostname = detectedHostname;
    hostConfig = {};  # Simplified - no complex host config needed
    hostFeatures = [];  # No features for simplified approach
    hostType = "desktop";
  };

  home = {
    username = "user";  # Hardcoded for now - SOPS secrets are system-level
    homeDirectory = "/home/user";
    stateVersion = "23.11";
  };

  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
    };
  };

  systemd.user.startServices = "sd-switch";

  # Add simple debugging info
  home.file.".config/home-manager/host-info.txt".text = ''
    Host: ${detectedHostname}
    Type: desktop
    State Version: 23.11
  '';


  # Add .local/bin and node_modules/bin to PATH
  home.sessionPath = [ "$HOME/.local/bin" "$HOME/node_modules/.bin" ];

  # Security tools
  home.packages = with pkgs; [
    age               # Modern encryption
    sops              # Secrets operations
    chkrootkit        # Rootkit scanner
    lynis             # Security auditing tool
    vulnix            # Nix vulnerability scanner
    nmap              # Network scanner
  ];

  # Simple security scripts
  home.file.".local/bin/security-scan" = {
    text = ''
      #!/usr/bin/env bash
      echo "🔍 Basic Security Scan"
      echo "===================="
      echo ""
      echo "📦 Checking for vulnerable packages..."
      vulnix --system 2>/dev/null | head -5 || echo "No critical vulnerabilities found"
      echo ""
      echo "🌐 Checking open ports..."
      nmap -sT localhost 2>/dev/null | grep open || echo "No open ports detected"
      echo ""
      echo "✅ Basic scan complete. Run 'lynis audit system' for detailed analysis."
    '';
    executable = true;
  };


  # Shell aliases
  home.shellAliases = {
    # Home Manager
    hm-switch = "home-manager switch --flake ~/Documents/dotfiles/#user@${detectedHostname}";
    hm-news = "home-manager news --flake ~/Documents/dotfiles/#user@${detectedHostname}";
    hm-gens = "home-manager generations";
    
    # Security
    security-scan = "~/.local/bin/security-scan";
    security-audit = "lynis audit system";
    rootkit-check = "sudo chkrootkit";
    
  };
}
