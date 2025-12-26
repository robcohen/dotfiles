# modules/htpc.nix
# Kodi HTPC module with streaming, gaming, and media addons
#
# Usage:
#   htpc.enable = true;
#   htpc.user = "kodi";
#   htpc.autoLogin = true;
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.htpc;

  kodiWithAddons = pkgs.kodi-wayland.withPackages (kodiPkgs: with kodiPkgs; [
    # Streaming
    youtube
    netflix
    invidious
    sendtokodi

    # DRM / Inputstream
    inputstream-adaptive
    inputstream-ffmpegdirect
    inputstream-rtmp
    inputstreamhelper

    # Library
    trakt
    trakt-module
    a4ksubtitles
    upnext
    infotagger

    # Filesystem
    vfs-libarchive
    vfs-rar
    vfs-sftp

    # Gaming (libretro/RetroPlayer)
    libretro
    libretro-snes9x
    libretro-mgba
    libretro-nestopia
    libretro-genplus
    joystick

    # Utils
    keymap
    simplejson
    requests
    routing
    six
    signals
  ]);
in
{
  options.htpc = {
    enable = lib.mkEnableOption "Kodi HTPC setup with Cage kiosk";

    user = lib.mkOption {
      type = lib.types.str;
      default = "kodi";
      description = "User to run Kodi as";
    };

    autoLogin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Auto-login to Kodi on boot";
    };

    extraAddons = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional Kodi addon packages";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create kodi user if not exists
    users.users.${cfg.user} = {
      isNormalUser = true;
      description = "Kodi HTPC User";
      extraGroups = [ "video" "audio" "input" "render" ];
      createHome = true;
    };

    # Cage kiosk compositor running Kodi
    services.cage = {
      enable = true;
      user = cfg.user;
      program = "${kodiWithAddons}/bin/kodi-standalone";
      environment = {
        QT_QPA_PLATFORM = "wayland";
        LIBVA_DRIVER_NAME = "iHD";
      };
    };

    # Auto-login
    services.displayManager.autoLogin = lib.mkIf cfg.autoLogin {
      enable = true;
      user = cfg.user;
    };

    # Audio via PipeWire
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # Media directories
    systemd.tmpfiles.rules = [
      "d /media 0755 ${cfg.user} users -"
      "d /media/movies 0755 ${cfg.user} users -"
      "d /media/tv 0755 ${cfg.user} users -"
      "d /media/music 0755 ${cfg.user} users -"
    ];

    # mDNS for network discovery
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
    };

    environment.systemPackages = [
      kodiWithAddons
      pkgs.yt-dlp
      pkgs.ffmpeg
    ];
  };
}
