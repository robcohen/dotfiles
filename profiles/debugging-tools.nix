{ config, pkgs, lib, hostname, hostConfig, hostFeatures, hostType, ... }:

let
  # Helper scripts for debugging home-manager configuration
  debugScript = pkgs.writeShellScriptBin "hm-debug" ''
    #!/bin/bash
    echo "🔍 Home Manager Debug Information"
    echo "================================="
    echo "Host: ${hostname}"
    echo "Type: ${hostType}"
    echo "Features: ${lib.concatStringsSep ", " hostFeatures}"
    echo ""
    echo "📁 Configuration Files:"
    find ~/.config/home-manager -name "*.txt" -o -name "*.md" | head -10
    echo ""
    echo "🏠 Home Manager Generation:"
    home-manager generations | head -5
    echo ""
    echo "📦 Active Packages Count:"
    nix-store --query --requisites ~/.nix-profile | wc -l
    echo ""
    echo "💾 Nix Store Size:"
    du -sh ~/.nix-profile
    echo ""
    echo "🔧 Recent Home Manager News:"
    home-manager news --flake ~/Documents/dotfiles/#user@${hostname} 2>/dev/null | head -10 || echo "No news available"
  '';

  configInspectScript = pkgs.writeShellScriptBin "hm-inspect" ''
    #!/bin/bash
    case "$1" in
      "packages")
        echo "📦 Installed Packages by Category:"
        echo "See ~/.config/home-manager/config-analysis.md for details"
        cat ~/.config/home-manager/config-analysis.md | grep -A 20 "Package Count"
        ;;
      "services")
        echo "⚙️  Active Services:"
        systemctl --user list-units --state=active | grep -E "(battery-monitor|disk-space|dunst|gpg-agent|syncthing)"
        ;;
      "features")
        echo "🎯 Host Features Analysis:"
        cat ~/.config/home-manager/config-analysis.md | grep -A 10 "Active Features"
        ;;
      "warnings")
        echo "⚠️  Configuration Warnings:"
        cat ~/.config/home-manager/config-analysis.md | grep -A 20 "Recommendations"
        ;;
      "all"|"")
        echo "🔍 Complete Configuration Overview:"
        cat ~/.config/home-manager/config-analysis.md
        ;;
      *)
        echo "Usage: hm-inspect [packages|services|features|warnings|all]"
        echo ""
        echo "Available options:"
        echo "  packages  - Show package information"
        echo "  services  - Show active services"
        echo "  features  - Show host features"
        echo "  warnings  - Show configuration warnings"
        echo "  all       - Show complete analysis"
        ;;
    esac
  '';

  nixCleanupScript = pkgs.writeShellScriptBin "hm-cleanup" ''
    #!/bin/bash
    echo "🧹 Home Manager Cleanup"
    echo "======================"

    echo "Current generations:"
    home-manager generations
    echo ""

    read -p "Remove old generations? (keep last 5) [y/N]: " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo "Removing old generations..."
      home-manager expire-generations '-5 days'
      echo "Running garbage collection..."
      nix-collect-garbage
      echo "✅ Cleanup complete"
    else
      echo "Cleanup cancelled"
    fi
  '';

  # Environment introspection
  environmentInfo = pkgs.writeShellScriptBin "hm-env" ''
    #!/bin/bash
    echo "🌍 Environment Information"
    echo "========================="
    echo "Hostname: $(hostname)"
    echo "User: $(whoami)"
    echo "Shell: $SHELL"
    echo "Desktop Session: ''${XDG_CURRENT_DESKTOP:-"None"}"
    echo "Wayland Display: ''${WAYLAND_DISPLAY:-"Not set"}"
    echo "X Display: ''${DISPLAY:-"Not set"}"
    echo ""
    echo "📍 XDG Directories:"
    echo "Config: $XDG_CONFIG_HOME"
    echo "Data: $XDG_DATA_HOME"
    echo "Cache: $XDG_CACHE_HOME"
    echo ""
    echo "🔧 Home Manager:"
    echo "State Version: ${hostConfig.homeManagerStateVersion}"
    echo "Profile: $(readlink ~/.nix-profile)"
    echo ""
    echo "💻 System Info:"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "NixOS Version: $(nixos-version 2>/dev/null || echo 'Not NixOS')"
  '';

in {
  # Install debugging tools
  home.packages = [
    debugScript
    configInspectScript
    nixCleanupScript
    environmentInfo
  ];

  # Create helpful documentation
  home.file.".config/home-manager/README.md".text = ''
    # Home Manager Configuration

    This directory contains generated configuration files and analysis reports.

    ## Quick Commands

    - `hm-debug` - Show debug information
    - `hm-inspect [category]` - Inspect configuration details
    - `hm-cleanup` - Clean old generations
    - `hm-env` - Show environment information

    ## Configuration Files

    - `config-analysis.md` - Detailed configuration analysis
    - `host-info.txt` - Basic host information

    ## Useful Home Manager Commands

    ```bash
    # Switch configuration
    home-manager switch --flake ~/Documents/dotfiles/#user@${hostname}

    # Show generations
    home-manager generations

    # Show news
    home-manager news

    # Remove old generations
    home-manager expire-generations '-7 days'
    ```

    ## Configuration Location

    Main configuration: `~/Documents/dotfiles/profiles/user.nix`
    Host-specific: `~/Documents/dotfiles/lib/vars.nix`
  '';

  # Add shell aliases for convenience
  home.shellAliases = {
    hm-switch = "home-manager switch --flake ~/Documents/dotfiles/#user@${hostname}";
    hm-news = "home-manager news --flake ~/Documents/dotfiles/#user@${hostname}";
    hm-gens = "home-manager generations";
    hm-build = "home-manager build --flake ~/Documents/dotfiles/#user@${hostname}";
  };
}
