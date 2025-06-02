# hosts/brix/configuration.nix
{ config, pkgs, lib, unstable, inputs, ... }:

let
  vars = import ../../lib/vars.nix;
in {
  imports = [
    ./hardware-configuration.nix
    ../common/base.nix
    ../common/security.nix
  ];


  networking.hostName = "brix";
  networking.networkmanager = {
    enable = true;
    wifi.macAddress = "random";
    ethernet.macAddress = "random";
  };


  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
  '';

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;
  hardware.bluetooth.settings.General = {
    ControllerMode = "bredr";
    JustWorksRepairing = "never";
    Privacy = "device";
  };


  hardware.enableRedistributableFirmware = true;
  hardware.firmware = with pkgs; [ linux-firmware sof-firmware ];
  hardware.cpu.intel.updateMicrocode = true;
  hardware.ledger.enable = true;
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
    "iwlwifi.power_save=0"
    "i915.enable_psr=0"
    "slab_nomerge"           # Prevent heap exploitation
    "init_on_alloc=1"        # Zero memory on allocation
    "init_on_free=1"         # Zero memory on free
    "page_alloc.shuffle=1"   # Randomize page allocator
    "fwupd.verbose=1"        # Verbose firmware logging
    "efi=debug"              # EFI debugging
    "lockdown=confidentiality" # Kernel lockdown mode
  ];
  boot.tmp.useTmpfs = true;

  # Plymouth boot splash screen
  boot.plymouth = {
    enable = true;
    theme = "breeze";
  };

  # Enable systemd in initrd for Plymouth LUKS integration
  boot.initrd.systemd.enable = true;

  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true;

  boot.loader.systemd-boot = {
    enable = true;
    editor = false;
    consoleMode = "0";
    configurationLimit = 10;  # Limit boot entries
  };
  boot.loader.efi.canTouchEfiVariables = true;

  systemd.packages = [ pkgs.observatory ];
  systemd.services.monitord.wantedBy = [ "multi-user.target" ];

  virtualisation.libvirtd = {
    enable = true;
    allowedBridges = [ "virbr0" ];
    qemu.swtpm.enable = true;
  };
  virtualisation.waydroid.enable = true;
  programs.virt-manager.enable = true;

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    defaultNetwork.settings = {
      dns_enabled = true;
      ipv6_enabled = false;
    };
  };

  swapDevices = [{
    device = vars.hosts.brix.swapPath;
    size = vars.hosts.brix.swapSize;
  }];

  users.users.${vars.user.name}.extraGroups = ["libvirtd" "adbusers"];

  environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = 1;


  environment.systemPackages = with pkgs; [
    # Container and device management
    podman-compose libimobiledevice ifuse
    # Graphics and hardware tools (system-level)
    vulkan-tools vulkan-loader vulkan-validation-layers
    libva-utils intel-gpu-tools mesa wayland wayland-utils wev efitools
    # Hardware monitoring (requires root access)
    lm_sensors smartmontools
  ];

  # TPM firmware protection
  security.tpm2 = {
    enable = true;
    tctiEnvironment.enable = true;
  };

  # Enhanced logging for firmware monitoring
  services.journald.extraConfig = ''
    SystemMaxUse=1G
    ForwardToSyslog=yes
  '';


  # Sandbox Wine applications
  programs.firejail.enable = true;

  # SSD optimizations
  services.fstrim.enable = true;  # Automatic TRIM

  # Container registry mirrors for faster pulls
  virtualisation.containers.registries.search = [
    "docker.io"
    "quay.io"
    "ghcr.io"
  ];

  # Automatic cleanup
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  virtualisation.podman.autoPrune = {
    enable = true;
    dates = "weekly";
    flags = [ "--all" ];
  };

  # Power management
  services.tlp.enable = true;                         # Battery optimization
  services.power-profiles-daemon.enable = false;     # Conflicts with TLP
  services.thermald.enable = true;                    # Thermal management


  # Better observability
  services.smartd.enable = true;  # Automatic disk health checks

  # Network monitoring
  services.vnstat.enable = true;  # Network usage statistics

  # Security auditing
  security.auditd.enable = true;  # System call auditing

  programs.adb.enable = true;
  services.pcscd.enable = true;
  services.usbmuxd.enable = true;

  # USB device security
  services.usbguard = {
    enable = true;
    rules = ''
      allow with-interface equals { 03:00:01 03:01:01 } # HID devices (keyboard/mouse)
      allow with-interface equals { 08:06:50 } # Mass storage
      allow with-interface equals { 09:00:00 } # USB hubs
      allow with-interface equals { 0e:01:01 } # Video devices
      allow with-interface equals { 01:01:00 01:02:00 } # Audio devices
      allow with-interface equals { ff:42:01 } # Android devices (ADB)
    '';
  };

  services.fwupd = {
    enable = true;

    # Verification & Sources - only official LVFS, no testing or P2P
    extraRemotes = [ "lvfs" ];

    # Security settings
    uefiCapsuleSettings = {
      DisableCapsuleUpdateOnDisk = true;  # Prevent persistent backdoors
      RequireESRTFwMgmt = true;          # Require ESRT firmware management
    };

    # Use default package (no P2P firmware sharing for security)
  };


}
