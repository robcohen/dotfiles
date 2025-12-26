# modules/arr-stack.nix
# Full *arr stack for automated media management
#
# Services:
#   - Prowlarr (indexer manager) - port 9696
#   - Radarr (movies) - port 7878
#   - Sonarr (TV shows) - port 8989
#   - Lidarr (music) - port 8686
#   - Readarr (books) - port 8787
#   - Bazarr (subtitles) - port 6767
#   - qBittorrent (downloads) - port 8080
#
# Usage:
#   arrStack.enable = true;
#   arrStack.mediaDir = "/media";
#   arrStack.downloadDir = "/media/downloads";
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.arrStack;
in
{
  options.arrStack = {
    enable = lib.mkEnableOption "Full *arr stack for media automation";

    user = lib.mkOption {
      type = lib.types.str;
      default = "media";
      description = "User to run *arr services as";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "media";
      description = "Group for *arr services";
    };

    mediaDir = lib.mkOption {
      type = lib.types.path;
      default = "/media";
      description = "Root media directory";
    };

    downloadDir = lib.mkOption {
      type = lib.types.path;
      default = "/media/downloads";
      description = "Download directory for torrents/usenet";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open firewall ports for *arr services";
    };

    # Individual service toggles
    prowlarr.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Prowlarr (indexer manager)";
    };

    radarr.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Radarr (movies)";
    };

    sonarr.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Sonarr (TV shows)";
    };

    lidarr.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Lidarr (music)";
    };

    readarr.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Readarr (books)";
    };

    bazarr.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Bazarr (subtitles)";
    };

    qbittorrent.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable qBittorrent download client";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create media user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.mediaDir;
      description = "Media services user";
    };
    users.groups.${cfg.group} = {};

    # Create directory structure
    systemd.tmpfiles.rules = [
      "d ${cfg.mediaDir} 0775 ${cfg.user} ${cfg.group} -"
      "d ${cfg.mediaDir}/movies 0775 ${cfg.user} ${cfg.group} -"
      "d ${cfg.mediaDir}/tv 0775 ${cfg.user} ${cfg.group} -"
      "d ${cfg.mediaDir}/music 0775 ${cfg.user} ${cfg.group} -"
      "d ${cfg.mediaDir}/books 0775 ${cfg.user} ${cfg.group} -"
      "d ${cfg.downloadDir} 0775 ${cfg.user} ${cfg.group} -"
      "d ${cfg.downloadDir}/complete 0775 ${cfg.user} ${cfg.group} -"
      "d ${cfg.downloadDir}/incomplete 0775 ${cfg.user} ${cfg.group} -"
    ];

    # Prowlarr - Indexer manager
    services.prowlarr = lib.mkIf cfg.prowlarr.enable {
      enable = true;
      openFirewall = cfg.openFirewall;
    };

    # Radarr - Movies
    services.radarr = lib.mkIf cfg.radarr.enable {
      enable = true;
      user = cfg.user;
      group = cfg.group;
      openFirewall = cfg.openFirewall;
    };

    # Sonarr - TV Shows
    services.sonarr = lib.mkIf cfg.sonarr.enable {
      enable = true;
      user = cfg.user;
      group = cfg.group;
      openFirewall = cfg.openFirewall;
    };

    # Lidarr - Music
    services.lidarr = lib.mkIf cfg.lidarr.enable {
      enable = true;
      user = cfg.user;
      group = cfg.group;
      openFirewall = cfg.openFirewall;
    };

    # Readarr - Books
    services.readarr = lib.mkIf cfg.readarr.enable {
      enable = true;
      user = cfg.user;
      group = cfg.group;
      openFirewall = cfg.openFirewall;
    };

    # Bazarr - Subtitles
    services.bazarr = lib.mkIf cfg.bazarr.enable {
      enable = true;
      user = cfg.user;
      group = cfg.group;
      openFirewall = cfg.openFirewall;
    };

    # qBittorrent
    systemd.services.qbittorrent = lib.mkIf cfg.qbittorrent.enable {
      description = "qBittorrent-nox";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox --webui-port=8080";
        Restart = "on-failure";
      };
    };

    # Firewall
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      lib.optional cfg.qbittorrent.enable 8080
    );

    # Packages
    environment.systemPackages = with pkgs; [
      qbittorrent-nox
    ];
  };
}
