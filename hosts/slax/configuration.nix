{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {

  imports = [
    ./hardware-configuration.nix
    ../../virtualization.nix
  ];

  nixpkgs = {
    overlays = [];
    config.allowUnfree = true;
  };

  nix.registry = (lib.mapAttrs (_: flake: { inherit flake; }))
    (lib.filterAttrs (_: lib.isType "flake") inputs);

  nix.nixPath = [ "/etc/nix/path" ];
  environment.etc = lib.mapAttrs'
    (name: value: {
      name = "nix/path/${name}";
      value.source = value.flake;
    })
    config.nix.registry;

  nix.settings = {
    experimental-features = "nix-command flakes";
    auto-optimise-store = true;
  };

  networking = {
    hostName = "slax";
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
    networkmanager.enable = true;
  };

  services.automatic-timezoned.enable = true;
  services.geoclue2.enable = true;

  time.timeZone = "America/Chicago";

  services.avahi = {
    enable = true;
    nssmdns = true;
    openFirewall = true;
  };

  hardware.logitech.wireless = {
    enable = true;
    enableGraphical = true;
  };

  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
    alsa.enable = true;
    jack.enable = true;
  };

  swapDevices = [{
    device = "/var/lib/swapfile";
    size = 32 * 1024;
  }];

  programs.fish.enable = true;

  users.users.user = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" "networkmanager" "input" "video" "libvirtd" "kvm" ];
  };

  i18n.defaultLocale = "en_US.UTF-8";

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  environment.variables = {
    LIBVA_DRIVER_NAME = "iHD";
    VDPAU_DRIVER = "va_gl";
    __GLX_VENDOR_LIBRARY_NAME = "mesa";
  };

  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;

  services.dbus.enable = true;
  services.fstrim.enable = true;

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.cosmic-greeter.enableGnomeKeyring = true;

  environment.systemPackages = with pkgs; [
    wget vim git
  ];

  system.stateVersion = "23.11";
}
