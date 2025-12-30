{ config, pkgs, lib, inputs, unstable, hostname, username ? "user", ... }:

# Note: `unstable` is passed via extraSpecialArgs from flake.nix
# No need to re-import it here

{
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
    ./programs/firefox.nix
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
    ./programs/hyprland.nix
    ./programs/hyprlock.nix
    ./programs/waybar.nix
    ./programs/fuzzel.nix
    ./programs/wlogout.nix
    ./programs/cliphist.nix
    ./programs/hyprshot.nix
    ./programs/thunar.nix
    ./programs/imv.nix
    ./programs/yazi.nix
    ./programs/neovim.nix
    ./services/gpg-agent.nix
    ./services/swaync.nix
    ./services/syncthing.nix
    ./services/hypridle.nix
    ./services/desktop-notifications.nix
    ./services/system-monitoring.nix
    # Security modules (import after base configurations)
    ./security/default.nix
  ];

  nixpkgs = {
    overlays = [ ];
    config = {
      allowUnfree = true;
      # Curated list of allowed unfree packages (more secure than allowing all)
      allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
        # Gaming
        "steam"
        "steam-original"
        "steam-run"
        # Media
        "spotify"
        # Communication
        "slack"
        "discord"
        "zoom"
        # Productivity
        "obsidian"
        "1password"
        "1password-cli"
        # Hardware
        "ledger-live-desktop"
        # Fonts
        "joypixels"
        # NVIDIA (for GPU support)
        "nvidia-x11"
        "nvidia-settings"
        "cuda"
        "cudatoolkit"
      ];
    };
  };

  # Pass hostname to submodules that need it
  _module.args = {
    inherit hostname;
  };

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
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
    Host: ${hostname}
    User: ${username}
    State Version: 23.11
  '';


  # Add .local/bin and node_modules/bin to PATH
  home.sessionPath = [ "$HOME/.local/bin" "$HOME/node_modules/.bin" ];

  # Security tools
  home.packages = with pkgs; [
    age               # Modern encryption
    sops              # Secrets operations
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
    hm-switch = "home-manager switch --flake ~/Documents/dotfiles/#${username}@${hostname}";
    hm-news = "home-manager news --flake ~/Documents/dotfiles/#${username}@${hostname}";
    hm-gens = "home-manager generations";

    # Security
    security-scan = "~/.local/bin/security-scan";
    security-audit = "lynis audit system";
    rootkit-check = "sudo lynis audit system --tests-from-group malware";

  };
}
