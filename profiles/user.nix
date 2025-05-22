{ config, pkgs, lib, inputs, ... }:

let
  unstable = import inputs.unstable-nixpkgs {
    system = pkgs.system;
    config.allowUnfree = true;
  };
in {
  imports = [
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
    ./services/gpg-agent.nix
    ./services/syncthing.nix
  ];

  nixpkgs = {
    overlays = [ ];
    config = {
      allowUnfree = true;
      allowUnfreePredicate = _: true;
    };
  };

  home = {
    username = "user";
    homeDirectory = "/home/user";
    stateVersion = "23.11";
  };

  systemd.user.startServices = "sd-switch";
}
