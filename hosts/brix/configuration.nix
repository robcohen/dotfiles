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
  #nix.nixPath = ["/etc/nix/path"];
  #environment.etc =
  #  lib.mapAttrs'
  #  (name: value: {
  #    name = "nix/path/${name}";
  #    value.source = value.flake;
  #  })
  #  config.nix.registry;

  nix.settings = {
    experimental-features = "nix-command flakes";
    auto-optimise-store = true;
  };

  ## Networking
  networking.hostName = "brix";
  networking.networkmanager.enable = true;
  networking.wireless.networks."ACC-Secure" = {
    auth = ''
      key_mgmt=WPA-EAP
      eap=TLS
      identity="r2145219@ACCstudent.austincc.edu"
      ca_cert="/home/user/Documents/certificates/ACC-CA.cer"
      private_key_passwd="CHANGEME"
      client_cert="/home/user/Documents/certificates/r2145219@ACCstudentaustinccedu.pem"
      private_key="/home/user/Documents/certificates/r2145219@ACCstudentaustinccedu.key"
    '';
  };
  networking.firewall.allowedTCPPorts = [ 8384 22000 ];
  networking.firewall.allowedUDPPorts = [ 22000 21027 ];

  services.automatic-timezoned.enable = true;
  services.geoclue2.enable = true;

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
  '';

  ## Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  ## Sound

  #sound.enable = true;
  #hardware.pulseaudio.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # OpenGL
  hardware.enableRedistributableFirmware = true;
  hardware.firmware = with pkgs; [
    linux-firmware
    sof-firmware
  ];
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

  # Boot Parameters
  boot.kernelPackages = inputs.unstable-nixpkgs.legacyPackages.${pkgs.system}.linuxPackages_latest;
  boot.kernelModules = [ "i915" ];
  boot.kernelParams = [ "acpi_enforce_resources=lax" "iwlwifi.power_save=0" ];  hardware.logitech.wireless.enable = true;
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

  swapDevices = [ {
    device = "/var/lib/swapfile";
    size = 32*1024;
  } ];

  programs.zsh.enable = true;

  users.users = {
    user = {
      isNormalUser = true;
      shell = pkgs.zsh;
      extraGroups = ["wheel" "networkmanager" "input" "video" "libvirtd" "adbusers"];
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

  environment.variables = {
    LIBVA_DRIVER_NAME = "iHD";  # Use Intel's media driver
    VDPAU_DRIVER = "va_gl";     # OpenGL-based VDPAU driver
    #WLR_NO_HARDWARE_CURSORS = "1";  # Can help with cursor issues on some Intel GPUs
    __GLX_VENDOR_LIBRARY_NAME = "mesa"; # Force use of Mesa drivers
  };
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };
  programs.adb.enable = true;

  services.pcscd.enable = true;
  services.usbmuxd.enable = true;
  services.syncthing = {
    enable = true;
    user = "user";
    dataDir = "/home/user/Documents";
    configDir = "/home/user/.config/syncthing";
    overrideDevices = false;     # overrides any devices added or deleted through the WebUI
    overrideFolders = false;     # overrides any folders added or deleted through the WebUI
    settings = {
      };
    };

  services.dbus.enable = true;

  services.ollama = {
    enable = true;
  };
  services.fwupd.enable = true;

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.user.enableGnomeKeyring = true;

  environment.systemPackages = with pkgs; [
    wget
    vim
    git
    podman-compose
    libimobiledevice
    ifuse
    wineWowPackages.waylandFull
    winetricks
    vulkan-tools
    vulkan-loader
    vulkan-validation-layers
    libva-utils
    intel-gpu-tools
    intel-media-driver
    intel-compute-runtime
    intel-ocl
    mesa
    wayland
    wayland-utils
    wev
    efitools
  ];

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.11";
}
