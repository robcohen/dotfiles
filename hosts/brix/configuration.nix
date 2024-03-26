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

  time.timeZone = "America/Chicago";
  ## Bluetooth

  services.blueman.enable = true;

  ## Sound

  #sound.enable = true;
  #hardware.pulseaudio.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  # Boot Parameters

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  programs.fish.enable = true;
  
  swapDevices = [ {
    device = "/var/lib/swapfile";
    size = 32*1024;
  } ];

  users.users = {
    user = {
      isNormalUser = true;
      shell = pkgs.fish;
      extraGroups = ["wheel" "networkmanager" "input" "video" "libvirtd"];
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

  services.dbus.enable = true;

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
