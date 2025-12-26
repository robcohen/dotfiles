{ inputs, pkgs, config, lib, ... }:

{
  nixpkgs = {
    overlays = [];
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [
        "python3.12-ecdsa-0.19.1"
      ];
    };
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
    # Use sops secret for password if available, with fallback for VM/ISO/appliance builds
    hashedPasswordFile = lib.mkIf (config ? sops && config.sops.secrets ? "user/hashedPassword")
      config.sops.secrets."user/hashedPassword".path;
    # Fallback: allow initial password for builds without sops (change on first boot)
    initialPassword = lib.mkIf (!(config ? sops && config.sops.secrets ? "user/hashedPassword")) "changeme";
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
    fuzzel          # Application launcher (native Wayland)
    swww            # Wallpaper daemon
    grim            # Screenshots
    slurp           # Screen selection
    wl-clipboard-rs # Clipboard utilities (Rust rewrite, faster)
    brightnessctl   # Brightness control
    pavucontrol     # Audio control GUI
  ];

  # Default for existing hosts; new hosts can override with their installation version
  system.stateVersion = lib.mkDefault "23.11";
}
