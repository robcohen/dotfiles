# hosts/brix/configuration.nix
{
  config,
  pkgs,
  lib,
  unstable,
  inputs,
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
  ];

  networking.hostName = "snix";
  networking.networkmanager = {
    enable = true;
    wifi.macAddress = "preserve"; # Keep hardware MAC to prevent disconnections
    ethernet.macAddress = "random";
    wifi.powersave = false; # Disable WiFi power saving to prevent disconnections
    wifi.scanRandMacAddress = false; # Don't randomize MAC during scans
  };

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"

    # MediaTek MT7925 PCIe WiFi/Bluetooth combo device support
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x14c3", ATTR{device}=="0x7925", RUN+="${pkgs.kmod}/bin/modprobe btusb && ${pkgs.kmod}/bin/modprobe btmtk"

    # Disable WiFi power management for MT7925e
    ACTION=="add", SUBSYSTEM=="net", KERNEL=="wlp*", DRIVERS=="mt7925e", RUN+="${pkgs.iw}/bin/iw dev %k set power_save off"

    # MediaTek MT7925 Bluetooth USB device support (if it appears as USB)
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", ATTR{idProduct}=="e616", ATTR{authorized}="1"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", ATTR{idProduct}=="e616", ATTR{power/autosuspend}="-1"

    # Intel AX211 Bluetooth device authorization and power management
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0033", ATTR{authorized}="1"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0033", ATTR{power/autosuspend}="-1"

    # General Bluetooth class device rules
    ACTION=="add", SUBSYSTEM=="bluetooth", RUN+="${pkgs.coreutils}/bin/chmod 666 /dev/rfkill"
    ACTION=="add", ATTR{class}=="e0*", ATTR{authorized}="1"

    # Force Bluetooth module loading for MT7925
    ACTION=="add", SUBSYSTEM=="net", KERNEL=="wlp*", DRIVERS=="mt7925e", RUN+="${pkgs.kmod}/bin/modprobe btusb", RUN+="${pkgs.kmod}/bin/modprobe btmtk"
  '';

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  hardware.bluetooth.package = pkgs.bluez;
  hardware.bluetooth.settings = {
    General = {
      Enable = "Source,Sink,Media,Socket";
      ControllerMode = "dual";
      JustWorksRepairing = "confirm";
      Privacy = "device";
      # Enhanced timeout and retry settings for firmware loading
      DiscoverableTimeout = 0;
      PairableTimeout = 0;
      AutoConnectTimeout = 60;
      # Experimental features that may help with MT7925
      Experimental = true;
      KernelExperimental = true;
    };
    Policy = {
      AutoEnable = true;
      ReconnectAttempts = 7;
      ReconnectIntervals = "1,2,4,8,16,32,64";
    };
  };
  services.blueman.enable = true;

  # SystemD service to disable WiFi power management for MT7925e
  systemd.services.wifi-power-management-fix = {
    description = "Disable WiFi power management for MT7925e";
    after = [ "network-pre.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.iw}/bin/iw dev wlp194s0 set power_save off 2>/dev/null || true; echo 0 > /sys/module/mt76_connac_lib/parameters/pm_enable 2>/dev/null || true'";
      ExecStartPost = "${pkgs.coreutils}/bin/sleep 2";
    };
  };

  # Allow Bluetooth firmware loading under kernel lockdown
  security.lockKernelModules = false; # Required for Bluetooth firmware loading

  hardware.enableRedistributableFirmware = true;
  hardware.firmware = with pkgs; [
    linux-firmware
    sof-firmware
    unstable.linux-firmware # Use unstable for latest MT7925 firmware
  ];
  hardware.cpu.intel.updateMicrocode = true;
  hardware.ledger.enable = true;
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      rocmPackages.clr.icd
      mesa
      vulkan-loader
      vulkan-validation-layers
      libva
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };

  # Try testing kernel for MT7925 Bluetooth fix
  boot.kernelPackages = pkgs.linuxPackages_testing;
  boot.kernelModules = [
    "amdgpu"
    "btusb"
    "btmtk"
    "btintel"
    "btrtl"
    "btbcm"
  ];
  # Load Bluetooth modules after system is ready
  boot.extraModulePackages = [ ];
  boot.extraModprobeConfig = ''
    options btusb reset=1 enable_autosuspend=0
    options bluetooth disable_ertm=1
    # MT7925e WiFi module options - disable power management for stability
    options mt7925e disable_aspm=1
    options mt76_connac_lib pm_enable=0
    options mt7925e power_save=0
    # MediaTek WiFi common options
    options mt76 disable_usb_sg=1
    # Force firmware loading retry
    options firmware_class path=/run/current-system/firmware
  '';
  boot.kernelParams = [
    "iwlwifi.power_save=0"
    "slab_nomerge" # Prevent heap exploitation
    "init_on_alloc=1" # Zero memory on allocation
    "init_on_free=1" # Zero memory on free
    "page_alloc.shuffle=1" # Randomize page allocator
    "fwupd.verbose=1" # Verbose firmware logging
    "efi=debug" # EFI debugging
    "lockdown=integrity" # Kernel lockdown mode (integrity allows signed firmware)

    # Bluetooth power management fixes
    "btusb.enable_autosuspend=0" # Disable Bluetooth auto-suspend
    "usbcore.autosuspend=-1" # Disable USB auto-suspend globally

    # Plymouth high resolution fix for AMD Radeon 860M
    "quiet" # Hide kernel messages for clean boot
    "splash" # Enable splash screen
    "vt.global_cursor_default=0" # Hide cursor during boot
    "amdgpu.dc=1" # Enable Display Core for better display handling
    "amdgpu.dpm=1" # Enable dynamic power management
    "video=eDP-1:1920x1080@60" # Force proper resolution (adjust if needed)
  ];
  boot.tmp.useTmpfs = true;

  # Plymouth boot splash screen with proper high resolution
  boot.plymouth = {
    enable = true;
    theme = "bgrt"; # BGRT uses system firmware logo, clean and works well
    # High resolution settings for crisp display
    extraConfig = ''
      DeviceScale=2
      ShowDelay=0
      DeviceTimeout=8
    '';
  };

  # Enable systemd in initrd for Plymouth LUKS integration
  boot.initrd.systemd.enable = true;

  # Use Rust-based bashless init for faster boot (NixOS 25.11+)
  # system.nixos-init.enable = true;
  # system.etc.overlay.enable = true;
  # services.userborn.enable = true;

  # Store password files in /var/lib/nixos for persistence with immutable /etc
  # services.userborn.passwordFilesLocation = "/var/lib/nixos";

  # Ensure sops-nix decrypts secrets before userborn runs
  # Note: sops-install-secrets-for-users handles neededForUsers secrets at early boot
  #systemd.services.userborn = {
  #  after = [ "sops-install-secrets-for-users.service" ];
  #  wants = [ "sops-install-secrets-for-users.service" ];
  #};

  # Load AMD graphics driver early for proper Plymouth resolution
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.initrd.availableKernelModules = [ "amdgpu" ];

  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true;

  boot.loader.systemd-boot = {
    enable = true;
    editor = false;
    consoleMode = "0";
    configurationLimit = 10; # Limit boot entries
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # Observatory package removed with COSMIC - consider alternative monitoring tools
  # systemd.packages = [ pkgs.observatory ];
  # systemd.services.monitord.wantedBy = [ "multi-user.target" ];

  virtualisation.libvirtd = {
    enable = true;
    allowedBridges = [ "virbr0" ];
    qemu.swtpm.enable = true;
    qemu.runAsRoot = false;
  };

  # Configure networking for libvirt
  networking.firewall.checkReversePath = false;
  networking.nftables.enable = false; # Use iptables instead
  networking.firewall.trustedInterfaces = [ "virbr0" ];

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

  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 32768; # 32GB swap
    }
  ];

  users.users.user.extraGroups = [
    "libvirtd"
    "adbusers"
    "tss"
    "disk"
  ];

  environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = 1;

  environment.systemPackages = with pkgs; [
    # Container and device management
    podman-compose
    libimobiledevice
    ifuse
    # Graphics and hardware tools (system-level)
    vulkan-tools
    vulkan-loader
    vulkan-validation-layers
    libva-utils
    intel-gpu-tools
    mesa
    wayland
    wayland-utils
    wev
    efitools
    # Hardware monitoring (requires root access)
    lm_sensors
    smartmontools
    # TPM and cryptographic tools
    tpm2-tools
    tpm2-pkcs11
    opensc
    # BIP39 and key derivation
    electrum
    python3Packages.mnemonic
    # Bluetooth debugging tools
    bluez
    bluez-tools
    # WiFi tools for power management
    iw
    wirelesstools
    # Networking tools for libvirt
    dnsmasq
  ];

  # TPM firmware protection
  security.tpm2 = {
    enable = true;
    tctiEnvironment.enable = true;
    pkcs11.enable = true; # Enable PKCS#11 interface
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
  services.fstrim.enable = true; # Automatic TRIM

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
  services.tlp = {
    enable = true; # Battery optimization
    settings = {
      # Disable WiFi power management
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "off";
      # Disable runtime power management for PCI devices (including WiFi)
      RUNTIME_PM_ON_AC = "on";
      RUNTIME_PM_ON_BAT = "on";
      # Blacklist MT7925e from runtime PM
      RUNTIME_PM_BLACKLIST = "c2:00.0"; # MT7925e PCI address
      # Disable USB autosuspend which can affect Bluetooth
      USB_AUTOSUSPEND = 0;
    };
  };
  services.power-profiles-daemon.enable = false; # Conflicts with TLP
  services.thermald.enable = true; # Thermal management

  # Logind configuration for lid handling and screen locking
  services.logind.settings.Login = {
    HandleLidSwitch = "lock"; # Lock screen when lid is closed
    HandleLidSwitchDocked = "lock"; # Lock even when docked
    HandleLidSwitchExternalPower = "lock"; # Lock even on AC power
    HandlePowerKey = "suspend";
    IdleAction = "lock";
    IdleActionSec = "15min";
  };

  # Better observability
  services.smartd.enable = true; # Automatic disk health checks

  # Network monitoring
  services.vnstat.enable = true; # Network usage statistics

  # Security auditing
  # TODO: Re-enable after configuring comprehensive AppArmor profiles to avoid audit_log_subj_ctx errors
  security.auditd.enable = false; # System call auditing - temporarily disabled

  programs.adb.enable = true;
  services.usbmuxd.enable = true;

  # USB device security with Bluetooth support (more permissive)
  services.usbguard = {
    enable = true;
    rules = ''
      # Allow all connected devices at boot
      allow with-connect-type "hotplug"

      # Allow Integrated Camera specifically (before class rules)
      allow id 5986:11af # Bison Integrated Camera

      # Allow MediaTek MT7925 Bluetooth explicitly (ThinkPad P16s Gen 4)
      allow id 0e8d:e025 # MediaTek MT7925 Bluetooth

      # Allow common device classes
      allow with-interface equals { 03:*:* } # All HID devices
      allow with-interface equals { 08:*:* } # All mass storage
      allow with-interface equals { 09:*:* } # All USB hubs
      allow with-interface equals { 0e:*:* } # All video devices
      allow with-interface equals { 01:*:* } # All audio devices
      allow with-interface equals { ff:*:* } # Vendor-specific (including ADB)

      # Bluetooth support
      allow with-interface equals { e0:*:* } # All Bluetooth controllers

      # Allow your specific hub
      allow id 0bda:5409 # 3-Port USB 2.1 Hub

      # Allow CASUE USB Keyboard
      allow id 2a7a:939f # CASUE USB KB

      # Allow mouse
      allow id 1c4f:0034 # Usb Mouse

      # Allow Ledger hardware wallets
      allow id 2c97:* # All Ledger devices

      # Allow other common vendors
      allow id 0bda:* # Realtek devices
      allow id 05e3:* # Genesys Logic hubs
      allow id 8087:* # Intel devices
      allow id 0e8d:* # MediaTek devices
    '';
  };

  services.fwupd = {
    enable = true;

    # Verification & Sources - only official LVFS, no testing or P2P
    extraRemotes = [ "lvfs" ];

    # Security settings - relaxed for Bluetooth compatibility
    uefiCapsuleSettings = {
      DisableCapsuleUpdateOnDisk = false; # Allow firmware updates for Bluetooth
      RequireESRTFwMgmt = false; # Relaxed for better firmware support
    };

    # Use default package (no P2P firmware sharing for security)
  };

}
