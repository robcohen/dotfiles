{ inputs, pkgs, config, lib, ... }:

{
  nixpkgs = {
    overlays = [];
    config.allowUnfree = true;
  };

  nix.registry = {
    nixpkgs.flake = inputs.stable-nixpkgs;
    unstable.flake = inputs.unstable-nixpkgs;
  };

  nix.settings = {
    trusted-users = [ "root" "user" ];
    experimental-features = "nix-command flakes";
    auto-optimise-store = true;
  };

  programs.zsh.enable = true;

  users.users.user = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "networkmanager" "input" "video" ];
  };

  i18n.defaultLocale = "en_US.UTF-8";

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  environment.variables = {
    LIBVA_DRIVER_NAME = "iHD";
    VDPAU_DRIVER = "va_gl";
    __GLX_VENDOR_LIBRARY_NAME = "mesa";
  };

  services.automatic-timezoned.enable = true;
  services.geoclue2.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Hyprland window manager
  programs.hyprland.enable = true;
  # SDDM is configured in sddm.nix module

  services.dbus.enable = true;
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  environment.systemPackages = with pkgs; [
    wget vim git
    # Hyprland essentials
    waybar          # Status bar
    dunst           # Notifications
    rofi-wayland    # Application launcher
    swww            # Wallpaper daemon
    grim            # Screenshots
    slurp           # Screen selection
    wl-clipboard    # Clipboard utilities
    brightnessctl   # Brightness control
    pavucontrol     # Audio control GUI
  ];

  system.stateVersion = "23.11";
}
