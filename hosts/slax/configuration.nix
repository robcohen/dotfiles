{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:

{

  imports = [
    ./hardware-configuration.nix
    ../common/base.nix
    ../common/security.nix
    ../common/tpm.nix
    ../common/sddm.nix
    ../common/swap.nix
    ../../modules/virtualization.nix
  ];

  # Virtualization with GPU passthrough for Looking Glass
  virtualization.vms = {
    enable = true;
    podman.enable = true;
    gpuPassthrough = {
      enable = true;
      gpuIds = "10de:2504,10de:228e"; # NVIDIA GPU
      iommu = "intel";
    };
    macos.enable = true;
    microvm = {
      enable = true;
      rednix.enable = true;
    };
  };


  networking = {
    hostName = "slax";
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
    networkmanager.enable = true;
  };


  hardware.logitech.wireless = {
    enable = true;
    enableGraphical = true;
  };

  services.pipewire.audio.enable = true;

  swapDevices = [{
    device = "/swap/swapfile";
    size = 16384;  # 16GB swap
  }];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.fstrim.enable = true;



}
