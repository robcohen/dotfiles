{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {

  imports = [
    ./hardware-configuration.nix
  ];

  nixpkgs = {
    overlays = [
    ];
    config = {
      allowUnfree = true;
    };
  };

  # This will add each flake input as a registry
  # To make nix3 commands consistent with your flake
  nix.registry = (lib.mapAttrs (_: flake: {inherit flake;})) ((lib.filterAttrs (_: lib.isType "flake")) inputs);

  # This will additionally add your inputs to the system's legacy channels
  # Making legacy nix commands consistent as well, awesome!
  nix.nixPath = ["/etc/nix/path"];
  environment.etc =
    lib.mapAttrs'
    (name: value: {
      name = "nix/path/${name}";
      value.source = value.flake;
    })
    config.nix.registry;

  nix.settings = {
    experimental-features = "nix-command flakes";
    auto-optimise-store = true;
  };
  
  ## Networking
  networking.hostName = "slax";
  networking.networkmanager.enable = true;
  
  time.timeZone = "America/Chicago";

  # Boot Parameters

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.luks.devices."luks-7e440f75-4329-441c-91e1-e131810f2b3a".device = "/dev/disk/by-uuid/7e440f75-4329-441c-91e1-e131810f2b3a";
  
  users.users = {
    user = {
      isNormalUser = true;
      extraGroups = ["wheel" "networkmanager" "video"];
    };
  };
  services.greetd = {
    enable = true;
    settings = {
      default_session.command = ''
        ${pkgs.greetd.tuigreet}/bin/tuigreet \
        --time \
        --asterisks \
        --user-menu \ 
        --cmd sway
      '';
    };
  };
  programs.sway.enable = true;
  
  environment.systemPackages = with pkgs; [
    wget
    vim
    git
  ];
  
  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.11";
}