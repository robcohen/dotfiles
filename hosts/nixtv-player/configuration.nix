# hosts/nixtv-player/configuration.nix
# nixtv-player: Lightweight media player client
#
# Target: Intel N100 mini PC (or similar) connected to TV
#
# Features:
#   - Kodi media center (local playback)
#   - Syncthing (sync media from nixtv-server)
#   - Tailscale (access Jellyfin on nixtv-server)
#   - Optional travel router mode
#
# Media is synced from nixtv-server via Syncthing, or streamed via Jellyfin.
{
  config,
  pkgs,
  lib,
  unstable,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../common/base.nix
    ../../modules/htpc.nix
    ../../modules/travel-router.nix
    ../../modules/tailscale-mullvad.nix
  ];

  # ==========================================================================
  # HTPC (Kodi) - Local playback
  # ==========================================================================
  htpc = {
    enable = true;
    user = "kodi";
    autoLogin = true;
  };

  # ==========================================================================
  # Travel Router (optional - enable when traveling)
  # ==========================================================================
  travelRouter = {
    enable = true;
    apInterface = "wlan0";  # Adjust based on actual interface name
    webUI.enable = true;
  };

  # ==========================================================================
  # Syncthing - Sync media from nixtv-server
  # ==========================================================================
  # After first boot, configure via http://localhost:8384
  # 1. Get device ID: syncthing -device-id
  # 2. Add nixtv-server as remote device
  # 3. Share /media folder with receive-only mode
  services.syncthing = {
    enable = true;
    user = "kodi";
    group = "users";
    dataDir = "/home/kodi";
    configDir = "/home/kodi/.config/syncthing";
    openDefaultPorts = true;
  };

  # Media directory
  systemd.tmpfiles.rules = [
    "d /media 0775 kodi users -"
    "d /media/movies 0775 kodi users -"
    "d /media/tv 0775 kodi users -"
    "d /media/music 0775 kodi users -"
  ];

  # ==========================================================================
  # System
  # ==========================================================================
  networking.hostName = "nixtv-player";

  # Admin user
  # Password options (in order of preference):
  #   1. SOPS secret at "nixtv/hashedPassword" if configured
  #   2. NIXTV_PASSWORD_HASH env var at build time: `mkpasswd -m sha-512`
  #   3. No password (SSH key required for access)
  users.users.nixtv = let
    envPasswordHash = builtins.getEnv "NIXTV_PASSWORD_HASH";
    hasSopsPassword = config ? sops && config.sops.secrets ? "nixtv/hashedPassword"; # noqa: secret
  in {
    isNormalUser = true;
    description = "nixTV Admin";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" "render" ];
    hashedPasswordFile = lib.mkIf hasSopsPassword config.sops.secrets."nixtv/hashedPassword".path;
    initialHashedPassword = lib.mkIf (!hasSopsPassword && envPasswordHash != "") envPasswordHash; # noqa: secret
  };

  # ==========================================================================
  # Intel N100 Graphics
  # ==========================================================================
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      libvdpau-va-gl
      intel-compute-runtime
    ];
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };

  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;

  # ==========================================================================
  # Boot
  # ==========================================================================
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [ "quiet" ];
  };

  # ==========================================================================
  # Services
  # ==========================================================================
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
  };

  services.thermald.enable = true;

  # ==========================================================================
  # Performance
  # ==========================================================================
  zramSwap.enable = true;
  powerManagement.cpuFreqGovernor = "schedutil";

  # ==========================================================================
  # Packages
  # ==========================================================================
  environment.systemPackages = with pkgs; [
    vim
    htop
    btop
    git
    wget
    curl
    tmux
    intel-gpu-tools
    libva-utils
    pciutils
    usbutils
  ];

  # ==========================================================================
  # Nix Settings
  # ==========================================================================
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  system.stateVersion = "25.11";
}
