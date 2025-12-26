# modules/jellyfin.nix
# Jellyfin media server with hardware transcoding
#
# Features:
#   - Intel Quick Sync (QSV) hardware transcoding for Intel N100
#   - Automatic library setup
#   - Tailscale-friendly (works over VPN)
#
# Usage:
#   mediaServer.jellyfin.enable = true;
#   mediaServer.jellyfin.mediaDir = "/media";
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.mediaServer.jellyfin;
in
{
  options.mediaServer.jellyfin = {
    enable = lib.mkEnableOption "Jellyfin media server with hardware transcoding";

    user = lib.mkOption {
      type = lib.types.str;
      default = "jellyfin";
      description = "User to run Jellyfin as";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "media";
      description = "Group for Jellyfin (shared with *arr stack)";
    };

    mediaDir = lib.mkOption {
      type = lib.types.path;
      default = "/media";
      description = "Root media directory";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open firewall ports for Jellyfin";
    };

    hardwareTranscoding = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Intel Quick Sync hardware transcoding";
    };
  };

  config = lib.mkIf cfg.enable {
    # Jellyfin service
    services.jellyfin = {
      enable = true;
      user = cfg.user;
      group = cfg.group;
      openFirewall = cfg.openFirewall;
    };

    # Add jellyfin user to video/render groups for hardware transcoding
    users.users.${cfg.user} = {
      extraGroups = lib.mkIf cfg.hardwareTranscoding [ "video" "render" ];
    };

    # Ensure media group exists
    users.groups.${cfg.group} = {};

    # Hardware transcoding support (Intel Quick Sync)
    hardware.graphics = lib.mkIf cfg.hardwareTranscoding {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver    # VAAPI driver for Intel
        intel-compute-runtime # OpenCL for tone mapping
        vpl-gpu-rt           # Intel Video Processing Library
      ];
    };

    # Intel media driver environment
    environment.sessionVariables = lib.mkIf cfg.hardwareTranscoding {
      LIBVA_DRIVER_NAME = "iHD";
    };

    # Media directories with proper permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.mediaDir} 0775 root ${cfg.group} -"
      "d ${cfg.mediaDir}/movies 0775 root ${cfg.group} -"
      "d ${cfg.mediaDir}/tv 0775 root ${cfg.group} -"
      "d ${cfg.mediaDir}/music 0775 root ${cfg.group} -"
      "d ${cfg.mediaDir}/books 0775 root ${cfg.group} -"
    ];

    # Useful packages
    environment.systemPackages = with pkgs; [
      jellyfin-web
      jellyfin-ffmpeg       # Jellyfin's ffmpeg with extra codec support
      libva-utils           # vainfo for debugging
      intel-gpu-tools       # intel_gpu_top for monitoring
    ];

    # Firewall - Jellyfin ports
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [
        8096  # HTTP
        8920  # HTTPS
      ];
      allowedUDPPorts = [
        1900  # DLNA discovery
        7359  # Client discovery
      ];
    };
  };
}
