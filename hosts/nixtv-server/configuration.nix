# hosts/nixtv/configuration.nix
# nixtv-server: Full media server + HTPC + Travel Router
#
# Target: Intel N100 mini PC connected to TV
#
# Features:
#   - Kodi media center with streaming addons (local playback)
#   - Jellyfin media server (transcoding, remote streaming)
#   - Full *arr stack (Radarr, Sonarr, Prowlarr, Lidarr, Readarr, Bazarr)
#   - Rclone sync from put.io
#   - Tailscale for secure remote access
#   - WiFi AP mode for travel router
#   - WireGuard VPN client
#
# Web UIs:
#   - Jellyfin:  http://nixtv:8096
#   - Radarr:    http://nixtv:7878
#   - Sonarr:    http://nixtv:8989
#   - Prowlarr:  http://nixtv:9696
#   - Lidarr:    http://nixtv:8686
#   - Readarr:   http://nixtv:8787
#   - Bazarr:    http://nixtv:6767
#   - qBittorrent: http://nixtv:8080
#   - Router UI: http://nixtv:80
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
    ../../modules/arr-stack.nix
    ../../modules/jellyfin.nix
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
  # Jellyfin - Transcoding & remote streaming
  # ==========================================================================
  mediaServer.jellyfin = {
    enable = true;
    mediaDir = "/media";
    hardwareTranscoding = true;  # Intel Quick Sync
  };

  # ==========================================================================
  # *arr Stack - Media automation
  # ==========================================================================
  arrStack = {
    enable = true;
    mediaDir = "/media";
    downloadDir = "/media/downloads";
    # All services enabled by default:
    # prowlarr, radarr, sonarr, lidarr, readarr, bazarr, qbittorrent
  };

  # ==========================================================================
  # Travel Router
  # ==========================================================================
  travelRouter = {
    enable = true;
    apInterface = "wlan0";  # Adjust based on actual interface name
    webUI.enable = true;
  };

  # ==========================================================================
  # Rclone - put.io sync
  # ==========================================================================
  environment.systemPackages = with pkgs; [
    rclone
    # System utilities
    vim
    htop
    btop
    git
    wget
    curl
    tmux
    # Hardware tools
    intel-gpu-tools
    libva-utils
    pciutils
    usbutils
    lshw
  ];

  # Rclone config directory
  systemd.tmpfiles.rules = [
    "d /var/lib/rclone 0700 root root -"
  ];

  # Rclone sync timer (hourly pull from put.io)
  systemd.services.rclone-putio-sync = {
    description = "Sync media from put.io";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.rclone}/bin/rclone sync putio: /media/downloads/putio --config /var/lib/rclone/rclone.conf --transfers 4 --checkers 8 --log-level INFO";
      User = "media";
      Group = "media";
    };
  };

  systemd.timers.rclone-putio-sync = {
    description = "Hourly put.io sync";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };

  # ==========================================================================
  # System
  # ==========================================================================
  networking.hostName = "nixtv-server";

  # Admin user (separate from kodi user)
  users.users.nixtv = {
    isNormalUser = true;
    description = "nixTV Admin";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" "render" "media" ];
    # Default initial password - change on first login
    hashedInitialPassword = "$6$Au0H3uGP4Kn1SFvk$7p9u5smKlvqfaARXzUcoWkWYwQMFJgXZ.Wc/QPSeuRmC5TrZO0oFmG0JSqKGZzcHEhj6hWkmShWl2l7WyhmMu.";
  };

  # Add kodi user to media group for shared access
  users.users.kodi.extraGroups = [ "media" ];

  # ==========================================================================
  # Intel N100 Graphics
  # ==========================================================================
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver    # VAAPI for newer Intel
      intel-vaapi-driver    # Older Intel
      libvdpau-va-gl
      intel-compute-runtime
      vpl-gpu-rt           # Intel Video Processing Library
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
  # Nix Settings (base.nix provides experimental-features and auto-optimise)
  # ==========================================================================
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  system.stateVersion = "25.11";
}
