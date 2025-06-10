# hosts/brix/configuration.nix
{ config, pkgs, lib, unstable, inputs, ... }:

let
  vars = import ../../lib/vars.nix;
in {
  imports = [
    ./hardware-configuration.nix
    ../common/base.nix
    ../common/security.nix
    ../common/tpm.nix
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
    
    # Intel AX211 Bluetooth device authorization and power management
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0033", ATTR{authorized}="1"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0033", ATTR{power/autosuspend}="-1"
    
    # General Bluetooth class device rules
    ACTION=="add", SUBSYSTEM=="bluetooth", RUN+="${pkgs.coreutils}/bin/chmod 666 /dev/rfkill"
    ACTION=="add", ATTR{class}=="e0*", ATTR{authorized}="1"
  '';

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  hardware.bluetooth.settings = {
    General = {
      ControllerMode = "dual";
      JustWorksRepairing = "confirm";
      Privacy = "device";
      # Enhanced timeout and retry settings for firmware loading
      DiscoverableTimeout = 0;
      PairableTimeout = 0;
      AutoConnectTimeout = 60;
    };
    Policy = {
      AutoEnable = true;
      ReconnectAttempts = 7;
      ReconnectIntervals = "1,2,4,8,16,32,64";
    };
  };
  services.blueman.enable = true;

  # Allow Bluetooth firmware loading under kernel lockdown
  security.lockKernelModules = false; # Required for Bluetooth firmware loading


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
    "lockdown=integrity"     # Kernel lockdown mode (integrity allows signed firmware)
    
    # Bluetooth power management fixes
    "btusb.enable_autosuspend=0"  # Disable Bluetooth auto-suspend
    "usbcore.autosuspend=-1"      # Disable USB auto-suspend globally
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

  users.users.${vars.user.name}.extraGroups = ["libvirtd" "adbusers" "tss"];

  environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = 1;


  environment.systemPackages = with pkgs; [
    # Container and device management
    podman-compose libimobiledevice ifuse
    # Graphics and hardware tools (system-level)
    vulkan-tools vulkan-loader vulkan-validation-layers
    libva-utils intel-gpu-tools mesa wayland wayland-utils wev efitools
    # Hardware monitoring (requires root access)
    lm_sensors smartmontools
    # TPM and cryptographic tools
    tpm2-tools tpm2-pkcs11 opensc
    # BIP39 and key derivation
    electrum python3Packages.mnemonic
  ];

  # TPM firmware protection
  security.tpm2 = {
    enable = true;
    tctiEnvironment.enable = true;
    pkcs11.enable = true;  # Enable PKCS#11 interface
  };

  # Smart card and PKCS#11 support
  services.pcscd = {
    enable = true;
    plugins = [ pkgs.tpm2-pkcs11 ];
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
  services.usbmuxd.enable = true;

  # USB device security with Bluetooth support
  services.usbguard = {
    enable = true;
    rules = ''
      allow with-interface equals { 03:00:01 03:01:01 } # HID devices (keyboard/mouse)
      allow with-interface equals { 08:06:50 } # Mass storage
      allow with-interface equals { 09:00:00 } # USB hubs
      allow with-interface equals { 0e:01:01 } # Video devices
      allow with-interface equals { 01:01:00 01:02:00 } # Audio devices
      allow with-interface equals { ff:42:01 } # Android devices (ADB)
      
      # Bluetooth support for Intel AX211
      allow with-interface equals { e0:01:01 } # Bluetooth wireless controller
      allow with-interface equals { e0:01:03 } # Bluetooth AMP controller  
      allow with-interface one-of { e0:01:01 e0:01:03 } # Either Bluetooth interface
      
      # Intel AX211 specific vendor/product (if needed)
      allow id 8087:0033 # Intel AX211 Bluetooth
    '';
  };

  services.fwupd = {
    enable = true;

    # Verification & Sources - only official LVFS, no testing or P2P
    extraRemotes = [ "lvfs" ];

    # Security settings - relaxed for Bluetooth compatibility
    uefiCapsuleSettings = {
      DisableCapsuleUpdateOnDisk = false;  # Allow firmware updates for Bluetooth
      RequireESRTFwMgmt = false;          # Relaxed for better firmware support
    };

    # Use default package (no P2P firmware sharing for security)
  };


}
