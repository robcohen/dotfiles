{ inputs, pkgs, config, lib, ... }:

{
  nixpkgs = {
    overlays = [];
    config = {
      allowUnfree = true;
      # Insecure packages - track for removal
      # See: https://github.com/NixOS/nixpkgs/issues (search for package name)
      # Review periodically and remove when fixed upstream
      permittedInsecurePackages = [
        # Required by: ledger-live-desktop
        # Issue: ECDSA timing side-channel vulnerability (CVE-2024-23342)
        # Tracking: https://github.com/LedgerHQ/ledger-live/issues/7458
        # Target: Remove when ledger-live >= 2.90.0 (expected Q1 2025)
        # Last checked: 2024-12-29
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

  users.users.user = let
    hasSopsPassword = config ? sops && config.sops.secrets ? "user/hashedPassword";
    envPasswordHash = builtins.getEnv "USER_PASSWORD_HASH";
  in {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "networkmanager" "input" "video" ];
    # Password priority: 1) SOPS secret, 2) env var hash, 3) no password (SSH only)
    hashedPasswordFile = lib.mkIf hasSopsPassword
      config.sops.secrets."user/hashedPassword".path;
    initialHashedPassword = lib.mkIf (!hasSopsPassword && envPasswordHash != "")
      envPasswordHash;
    # Note: If neither SOPS nor env var is set, user has no password (SSH key required)
    openssh.authorizedKeys.keys = [
      # Phone (Termux)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINrIkZyfMS54UscUqtoQoHYf+VIXPyM5fRt5frgGE7sI u0_a194@localhost"
    ];
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
