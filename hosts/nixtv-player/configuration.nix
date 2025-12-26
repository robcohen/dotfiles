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
  users.users.nixtv = {
    isNormalUser = true;
    description = "nixTV Admin";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" "render" ];
    # Default initial password - change on first login
    hashedInitialPassword = "$6$Au0H3uGP4Kn1SFvk$7p9u5smKlvqfaARXzUcoWkWYwQMFJgXZ.Wc/QPSeuRmC5TrZO0oFmG0JSqKGZzcHEhj6hWkmShWl2l7WyhmMu.";
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
