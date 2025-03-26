# hosts/brix/configuration.nix
{ config, pkgs, lib, unstable, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../ledger.nix
    ../syncthing.nix
  ];

  nixpkgs = {
    overlays = [ ];
    config.allowUnfree = true;
  };

  nix.registry = {
    nixpkgs.flake = inputs.stable-nixpkgs;
    unstable.flake = inputs.unstable-nixpkgs;
  };

  nix.settings = {
    trusted-users = [ "root" "user" ];
    experimental-features = "nix-command flakes";
    auto-optimise-store = true;
    substituters = [ "https://cosmic.cachix.org" ];
    trusted-public-keys = [ "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE=" ];
      };

  networking.hostName = "brix";
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ 8384 22000 ];
  networking.firewall.allowedUDPPorts = [ 22000 21027 ];

  services.automatic-timezoned.enable = true;
  services.geoclue2.enable = true;

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
  '';

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    jack.enable = true;
  };

  services.coredns = {
    enable = true;
    config = ''
      . {
        forward . 1.1.1.1 8.8.8.8
      }

      eth. {
        forward . resolver.ens.domains
      }
    '';
  };


  hardware.enableRedistributableFirmware = true;
  hardware.firmware = with pkgs; [ linux-firmware sof-firmware ];

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-compute-runtime
      vaapiIntel
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  boot.kernelPackages = unstable.linuxPackages_latest;
  boot.kernelModules = [ "i915" ];
  boot.kernelParams = [
    "acpi_enforce_resources=lax"
    "iwlwifi.power_save=0"
    "i915.enable_psr=0"
  ];
  boot.tmp.useTmpfs = true;

  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  swapDevices = [{
    device = "/swapfile";
    size = 32 * 1024;
  }];

  programs.zsh.enable = true;

  users.users.user = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = ["wheel" "networkmanager" "input" "video" "libvirtd" "adbusers"];
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

  environment.systemPackages = with pkgs; [
    wget vim git podman-compose libimobiledevice ifuse
    wineWowPackages.waylandFull winetricks
    vulkan-tools vulkan-loader vulkan-validation-layers
    libva-utils intel-gpu-tools mesa wayland wayland-utils wev efitools
  ];

  programs.adb.enable = true;
  services.pcscd.enable = true;
  services.usbmuxd.enable = true;

  services.dbus.enable = true;
  services.ollama.enable = true;
  services.fwupd.enable = true;

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.cosmic-greeter.enableGnomeKeyring = true;

  system.stateVersion = "23.11";
}
