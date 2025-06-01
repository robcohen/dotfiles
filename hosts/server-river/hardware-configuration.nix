# Hardware configuration for server-river
# This is a template - adjust for your actual hardware

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ]; # or "kvm-amd" for AMD
  boot.extraModulePackages = [ ];

  # Root filesystem - adjust to your setup
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/CHANGE-ME";
    fsType = "ext4";
  };

  # Boot partition
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/CHANGE-ME";
    fsType = "vfat";
  };

  # ZFS pool for data - adjust to your setup
  fileSystems."/tank" = {
    device = "tank";
    fsType = "zfs";
  };

  # Enable UEFI boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Hardware-specific settings
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  # hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware; # for AMD

  # Network interface
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp1s0.useDHCP = lib.mkDefault true; # adjust interface name

  # TPM support
  boot.initrd.luks.devices = {}; # Add LUKS config if needed
}