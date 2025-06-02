{ config, pkgs, lib, inputs, ... }:

let
  vars = import ../lib/vars.nix;
  
  # Simple hostname detection with fallback
  detectedHostname = "brix";  # Hardcode for now to avoid infinite recursion
  
  # Get host config 
  hostConfig = vars.hosts.${detectedHostname} or {};
  
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
    hostConfig = hostConfig;
    hostFeatures = hostConfig.features or [];
    hostType = hostConfig.type or "desktop";
  };

  home = {
    username = vars.user.name;
    homeDirectory = vars.user.home;
    stateVersion = hostConfig.homeManagerStateVersion or "23.11";
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
    Type: ${hostConfig.type or "desktop"}
    Features: ${lib.concatStringsSep ", " (hostConfig.features or [])}
    State Version: ${hostConfig.homeManagerStateVersion or "23.11"}
  '';

  # Add useful shell aliases for home-manager
  home.shellAliases = {
    hm-switch = "home-manager switch --flake ~/Documents/dotfiles/#user@${detectedHostname}";
    hm-news = "home-manager news --flake ~/Documents/dotfiles/#user@${detectedHostname}";
    hm-gens = "home-manager generations";
  };
}
