{ config, pkgs, lib, inputs, ... }:

let
  vars = import ../lib/vars.nix;
  hostname = builtins.readFile /etc/hostname;
  hostConfig = vars.hosts.${lib.strings.removeSuffix "\n" hostname} or {};
  unstable = import inputs.unstable-nixpkgs {
    system = pkgs.system;
    config.allowUnfree = true;
  };
in {
  imports = [
    ./validation.nix
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
}
