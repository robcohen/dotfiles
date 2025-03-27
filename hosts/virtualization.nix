{ config, lib, pkgs, ... }:

{
  # Boot and Kernel Setup for VFIO / KVMFR
  boot.extraModulePackages = with config.boot.kernelPackages; [ kvmfr ];
  boot.kernelModules = [ "kvmfr" "vfio_virqfd" "vfio_pci" "vfio_iommu_type1" "vfio" ];
  boot.blacklistedKernelModules = [ "nvidia" "nouveau" ];
  boot.extraModprobeConfig = ''
    options kvmfr static_size_mb=128
    options vfio-pci ids=10de:2504,10de:228e
  '';
  boot.kernelParams = [ "intel_iommu=on" ];

  # Udev rules for device access
  services.udev.extraRules = ''
    SUBSYSTEM=="kvmfr", OWNER="user", GROUP="kvm", MODE="0660"
    SUBSYSTEM=="vfio", OWNER="user", GROUP="kvm", MODE="0660"
  '';

  # Bootloader (only include if not already configured globally)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Virtualization Tools
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      ovmf = {
        enable = true;
        packages = [ pkgs.OVMFFull.fd ];
      };
      swtpm.enable = true;
    };
  };

  programs.virt-manager.enable = true;

  # Podman / Docker Compatibility
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  users.groups.kvm.members = [ "user" ];
  users.groups.libvirtd.members = [ "user" ];
}
