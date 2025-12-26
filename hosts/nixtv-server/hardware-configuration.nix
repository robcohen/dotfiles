# hosts/nixtv/hardware-configuration.nix
# PLACEHOLDER - Generate with: nixos-generate-config --show-hardware-config
#
# Target hardware: Intel N100 mini PC (or similar)
# - Intel N100 CPU with Intel UHD Graphics
# - WiFi card supporting AP mode
# - HDMI/DisplayPort output for TV
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Boot - adjust based on actual hardware
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usb_storage"
    "sd_mod"
    "sdhci_pci"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Filesystems - PLACEHOLDER: Update after installation
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  swapDevices = [ ];

  # Networking - placeholder interface names
  # Update these based on actual hardware (ip link show)
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Intel N100 specific
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
