{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {

  imports = [
    ./hardware-configuration.nix
    ../ledger.nix
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
  networking = {
      hostName = "slax";
      nameservers = [ "1.1.1.1" "8.8.8.8" ];
      networkmanager.enable = true;
  };
  
  time.timeZone = "America/Chicago";

  ## Printing

  services.printing.enable = true;
  services.printing.drivers = [ pkgs.cups-brother-hll2350dw ];
  services.avahi = {
    enable = true;
    nssmdns = true;
    openFirewall = true;
  };
  ## Mouse
  # Logitech receiver
  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true;

  ## Sound

  hardware.pulseaudio.enable = true;

  # Boot Parameters
  boot.extraModulePackages = with config.boot.kernelPackages; [ kvmfr ];
  boot.kernelModules  = [ "kvmfr" "vfio_virqfd" "vfio_pci" "vfio_iommu_type1" "vfio" ];
  boot.blacklistedKernelModules = [ "nvidia" "nouveau" ];
  boot.extraModprobeConfig = "
    options kvmfr static_size_mb=128
    options vfio-pci ids=10de:2504,10de:228e
  "; 
  services.udev.extraRules = ''                                                                
    SUBSYSTEM=="kvmfr", OWNER="user", GROUP="kvm", MODE="0660"
    SUBSYSTEM=="vfio", OWNER="user", GROUP="kvm", MODE="0660"
  ''; 
  boot.loader.systemd-boot.enable = true;
  boot.kernelParams = [ "intel_iommu=on" ];
 

  boot.loader.efi.canTouchEfiVariables = true;
  virtualisation.libvirtd = {
    enable = true;

    qemu = {
      package = pkgs.qemu_kvm;
      ovmf = {
        enable = true;
        packages = [];##pkgs.OVMFFull.fd];
      };
      swtpm.enable = true;
    };
  };
  programs.virt-manager.enable = true;
  
  virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
  };

  programs.fish.enable = true;
  
  swapDevices = [ {
    device = "/var/lib/swapfile";
    size = 32*1024;
  } ];
  
  users.users = {
    user = {
      isNormalUser = true;
      shell = pkgs.bash;
      extraGroups = ["wheel" "networkmanager" "input" "video" "libvirtd" "kvm"];
    };
  };

  i18n.defaultLocale = "en_US.UTF-8";

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd sway";
        user = "greeter";
      };
    };
  };
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };
  programs.thunar.enable = true;
  services.dbus.enable = true;
  services.fstrim.enable = true;
  services.kubo = {
    enable = true;
  }; 
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.user.enableGnomeKeyring = true;
  environment.systemPackages = with pkgs; [
    wget
    vim
    git
  ];
  
  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.11";
}
