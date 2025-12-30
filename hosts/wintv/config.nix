# hosts/wintv/config.nix
# Declarative configuration for the wintv Windows host
#
# This defines:
#   - Windows host state (features, packages, firewall)
#   - Container services (media, AI, identity)
#   - Configuration files
#
# Build with: nix build .#wintv-config
# Deploy with: ./result/deploy.ps1

{ lib, ... }:

let
  # Common environment variables for LinuxServer.io containers
  linuxServerEnv = {
    PUID = "1000";
    PGID = "1000";
    TZ = "America/New_York";
  };

  # Common paths
  appData = "C:/ProgramData/wintv";
  mediaPath = "C:/Media";
in {
  wintv = {
    enable = true;

    hostname = "wintv";
    domain = "wintv.lorikeet-crested.ts.net";
    timezone = "America/New_York";

    paths = {
      media = "C:\\Media";
      appData = "C:\\ProgramData\\wintv";
    };

    # =========================================================================
    # Windows Host Configuration
    # =========================================================================
    windows = {
      features = [
        "Containers"
        "Microsoft-Hyper-V-All"
        "VirtualMachinePlatform"
      ];

      packages = [
        "RedHat.Podman-Desktop"
        "Tailscale.Tailscale"
        "VideoLAN.VLC"
        "Microsoft.WindowsTerminal"
        "Git.Git"
        "XBMCFoundation.Kodi"  # Media center frontend
        "Rclone.Rclone"        # Cloud storage mount for put.io
      ];

      # Auto-login for appliance mode (no login screen)
      autoLogin = {
        enable = true;
        username = "User";
      };

      # Kodi auto-start configuration
      # TODO: Add shell replacement mode for full kiosk experience
      #       This would replace Explorer with Kodi entirely
      kiosk = {
        enable = true;
        application = "kodi";
        # shellReplacement = false;  # Future: replace Explorer with Kodi
      };

      # Run Podman as a system service (starts at boot, not user login)
      podmanSystemService = true;
    };

    # =========================================================================
    # Kodi Media Center Configuration
    # =========================================================================
    kodi = {
      enable = true;

      jellyfin = {
        enable = true;
        serverUrl = "http://localhost:8096";  # Local Jellyfin container
        syncMode = "native";  # Sync to Kodi's native library
      };

      video = {
        resolution = "4k";
        hdr = true;
        refreshRateMatching = "always";  # Match content framerate
      };

      audio = {
        passthrough = true;
        formats = [ "ac3" "eac3" "truehd" "dts" "dtshd" ];
        atmos = true;
      };

      ui = {
        skin = "arctic-horizon-2";  # Modern Netflix-style theme
        startWindow = "home";
        screensaverTimeout = 5;
      };

      performance = {
        bufferSize = 104857600;  # 100MB buffer for 4K streaming
        readFactor = 8.0;
      };
    };

    # =========================================================================
    # Rclone Cloud Storage (put.io integration)
    # =========================================================================
    rclone = {
      enable = true;

      putio = {
        enable = true;
        # OAuth token must be configured manually via: rclone config
        # This creates a union mount that merges local + remote
        mountDrive = "P";  # put.io mounted as P:\
        unionDrive = "M";  # Union mount (local + remote) as M:\
      };

      sync = {
        enable = true;
        # Move files from put.io to local (frees put.io space)
        destination = "C:\\Media\\Cloud";
        intervalMinutes = 30;
        minAge = "60m";  # Don't move files still being uploaded
        deleteAfterSync = true;  # Remove from put.io after local copy
      };
    };

    windows.firewall.rules = {
      Jellyfin = { port = 8096; description = "Jellyfin Media Server"; };
      JellyfinHTTPS = { port = 8920; description = "Jellyfin HTTPS"; };
      Radarr = { port = 7878; description = "Radarr Movie Manager"; };
      Sonarr = { port = 8989; description = "Sonarr TV Manager"; };
      Prowlarr = { port = 9696; description = "Prowlarr Indexer"; };
      Lidarr = { port = 8686; description = "Lidarr Music Manager"; };
      Readarr = { port = 8787; description = "Readarr Book Manager"; };
      Bazarr = { port = 6767; description = "Bazarr Subtitles"; };
      qBittorrent = { port = 8080; description = "qBittorrent WebUI"; };
      qBittorrentTorrent = { port = 6881; description = "qBittorrent Torrent"; protocol = "Any"; };
      Ollama = { port = 11434; description = "Ollama LLM API"; };
      OpenWebUI = { port = 3000; description = "Open WebUI"; };
      Kanidm = { port = 443; description = "Kanidm Identity Provider"; };
    };

    # =========================================================================
    # Container Definitions
    # =========================================================================
    containers = {
      # --- Identity & Auth ---
      kanidm = {
        enable = true;
        image = "kanidm/server:latest";
        ports = [ "443:8443" ];
        volumes = [
          "C:/ProgramData/wintv/Kanidm:/data"
          "C:/ProgramData/wintv/certs:/data/certs:ro"
        ];
        tmpfs = [ "/run/kanidm" ];
        environment.TZ = "America/New_York";
      };

      # --- Media Server ---
      jellyfin = {
        enable = true;
        image = "jellyfin/jellyfin:latest";
        gpu = true;
        ports = [
          "8096:8096"
          "8920:8920"
          "1900:1900/udp"
          "7359:7359/udp"
        ];
        volumes = [
          "C:/ProgramData/wintv/Jellyfin/config:/config"
          "C:/ProgramData/wintv/Jellyfin/cache:/cache"
          "C:/Media:/media:ro"
        ];
        environment = {
          NVIDIA_VISIBLE_DEVICES = "all";
          NVIDIA_DRIVER_CAPABILITIES = "all";
        };
      };

      # --- AI/LLM ---
      ollama = {
        enable = true;
        image = "ollama/ollama:latest";
        gpu = true;
        ports = [ "11434:11434" ];
        volumes = [ "C:/ProgramData/wintv/Ollama:/root/.ollama" ];
        environment.NVIDIA_VISIBLE_DEVICES = "all";
      };

      open-webui = {
        enable = true;
        image = "ghcr.io/open-webui/open-webui:main";
        ports = [ "3000:8080" ];
        volumes = [ "C:/ProgramData/wintv/OpenWebUI:/app/backend/data" ];
        environment.OLLAMA_BASE_URL = "http://ollama:11434";
        dependsOn = [ "ollama" ];
      };

      # --- Arr Stack ---
      prowlarr = {
        enable = true;
        image = "lscr.io/linuxserver/prowlarr:latest";
        ports = [ "9696:9696" ];
        volumes = [ "${appData}/Prowlarr:/config" ];
        environment = linuxServerEnv;
      };

      radarr = {
        enable = true;
        image = "lscr.io/linuxserver/radarr:latest";
        ports = [ "7878:7878" ];
        volumes = [
          "${appData}/Radarr:/config"
          "${mediaPath}/Movies:/movies"
          "${mediaPath}/Downloads:/downloads"
        ];
        environment = linuxServerEnv;
        dependsOn = [ "prowlarr" ];
      };

      sonarr = {
        enable = true;
        image = "lscr.io/linuxserver/sonarr:latest";
        ports = [ "8989:8989" ];
        volumes = [
          "${appData}/Sonarr:/config"
          "${mediaPath}/TV:/tv"
          "${mediaPath}/Downloads:/downloads"
        ];
        environment = linuxServerEnv;
        dependsOn = [ "prowlarr" ];
      };

      lidarr = {
        enable = true;
        image = "lscr.io/linuxserver/lidarr:latest";
        ports = [ "8686:8686" ];
        volumes = [
          "${appData}/Lidarr:/config"
          "${mediaPath}/Music:/music"
          "${mediaPath}/Downloads:/downloads"
        ];
        environment = linuxServerEnv;
        dependsOn = [ "prowlarr" ];
      };

      readarr = {
        enable = true;
        image = "ghcr.io/hotio/readarr:latest";
        ports = [ "8787:8787" ];
        volumes = [
          "${appData}/Readarr:/config"
          "${mediaPath}/Books:/books"
          "${mediaPath}/Downloads:/downloads"
        ];
        environment = linuxServerEnv;
        dependsOn = [ "prowlarr" ];
      };

      bazarr = {
        enable = true;
        image = "lscr.io/linuxserver/bazarr:latest";
        ports = [ "6767:6767" ];
        volumes = [
          "${appData}/Bazarr:/config"
          "${mediaPath}/Movies:/movies"
          "${mediaPath}/TV:/tv"
        ];
        environment = linuxServerEnv;
        dependsOn = [ "radarr" "sonarr" ];
      };

      # --- Download Client ---
      qbittorrent = {
        enable = true;
        image = "lscr.io/linuxserver/qbittorrent:latest";
        ports = [
          "8080:8080"
          "6881:6881"
          "6881:6881/udp"
        ];
        volumes = [
          "${appData}/qBittorrent:/config"
          "${mediaPath}/Downloads:/downloads"
        ];
        environment = linuxServerEnv // {
          WEBUI_PORT = "8080";
        };
      };

      # --- Auto-update ---
      watchtower = {
        enable = true;
        image = "containrrr/watchtower:latest";
        volumes = [
          "/run/podman/podman.sock:/var/run/docker.sock"
        ];
        environment = {
          TZ = "America/New_York";
          WATCHTOWER_CLEANUP = "true";
          WATCHTOWER_SCHEDULE = "0 0 4 * * *";
        };
      };
    };
  };
}
