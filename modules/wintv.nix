# modules/wintv.nix
# Declarative Windows + Podman container configuration
#
# Generates:
#   - WinGet Configuration YAML (Windows features, packages, firewall)
#   - docker-compose.yml (container definitions)
#   - Config files (Caddyfile, kanidm-server.toml, etc.)
#   - Deploy script
#
# Usage:
#   nix build .#wintv-config
#   ./result/deploy.ps1

{ config, lib, pkgs, ... }:

let
  cfg = config.wintv;

  # Note: Container generation is done by lib/wintv-generators.nix
  # This module only defines the options schema

  # Container option type
  containerOpts = lib.types.submodule {
    options = {
      enable = lib.mkEnableOption "this container";

      image = lib.mkOption {
        type = lib.types.str;
        description = "Container image to use";
      };

      ports = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Port mappings (host:container)";
        example = [ "8096:8096" "8920:8920" ];
      };

      volumes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Volume mounts";
        example = [ "/mnt/c/ProgramData/wintv/Jellyfin:/config" ];
      };

      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Environment variables";
      };

      gpu = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable NVIDIA GPU passthrough for hardware acceleration (transcoding, AI inference)";
      };

      dependsOn = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "List of container names this container depends on. Containers will start in dependency order.";
        example = [ "prowlarr" "ollama" ];
      };

      restart = lib.mkOption {
        type = lib.types.str;
        default = "unless-stopped";
        description = "Restart policy";
      };

      tmpfs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "tmpfs mounts";
      };

      healthcheck = lib.mkOption {
        type = lib.types.nullOr (lib.types.submodule {
          options = {
            test = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "Command to run for health check";
              example = [ "CMD" "curl" "-f" "http://localhost:8080/health" ];
            };
            interval = lib.mkOption {
              type = lib.types.str;
              default = "30s";
              description = "Time between health checks";
            };
            timeout = lib.mkOption {
              type = lib.types.str;
              default = "10s";
              description = "Time to wait for health check response";
            };
            retries = lib.mkOption {
              type = lib.types.int;
              default = 3;
              description = "Number of consecutive failures before marking unhealthy";
            };
          };
        });
        default = null;
        description = "Container healthcheck configuration with structured options";
      };

      extraConfig = lib.mkOption {
        type = lib.types.attrs;
        default = {};
        description = "Extra docker-compose configuration";
      };
    };
  };

  # Port type that validates range (1-65535) or port range strings
  portType = lib.types.either
    (lib.types.ints.between 1 65535)
    (lib.types.strMatching "^[0-9]+-[0-9]+$");

  # Firewall rule option type
  firewallRuleOpts = lib.types.submodule {
    options = {
      port = lib.mkOption {
        type = portType;
        description = "Port number (1-65535) or range (e.g., '8000-8100')";
        example = 8080;
      };

      protocol = lib.mkOption {
        type = lib.types.enum [ "TCP" "UDP" "Any" ];
        default = "TCP";
        description = "Protocol";
      };

      description = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Rule description";
      };
    };
  };

in {
  options.wintv = {
    enable = lib.mkEnableOption "WinTV declarative configuration";

    hostname = lib.mkOption {
      type = lib.types.str;
      default = "wintv";
      description = "Windows hostname";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      example = "wintv.lorikeet-crested.ts.net";
      description = "Tailscale domain for this host";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "America/New_York";
      description = "Timezone for containers";
    };

    paths = {
      media = lib.mkOption {
        type = lib.types.str;
        default = "C:\\Media";
        description = "Media storage path (Windows format)";
      };

      appData = lib.mkOption {
        type = lib.types.str;
        default = "C:\\ProgramData\\wintv";
        description = "Application data path (Windows format)";
      };

      # WSL-formatted paths (auto-generated from Windows paths)
      mediaWsl = lib.mkOption {
        type = lib.types.str;
        internal = true;
        readOnly = true;
        default = "/mnt/c/Media";
        description = "Auto-generated WSL path for media directory";
      };

      appDataWsl = lib.mkOption {
        type = lib.types.str;
        internal = true;
        readOnly = true;
        default = "/mnt/c/ProgramData/wintv";
        description = "Auto-generated WSL path for application data";
      };
    };

    windows = {
      features = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "Containers" "Microsoft-Hyper-V-All" ];
        description = "Windows optional features to enable";
      };

      packages = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "RedHat.Podman-Desktop"
          "Tailscale.Tailscale"
        ];
        description = "WinGet package IDs to install";
      };

      firewall = {
        rules = lib.mkOption {
          type = lib.types.attrsOf firewallRuleOpts;
          default = {};
          description = "Windows Firewall rules";
        };
      };

      autoLogin = {
        enable = lib.mkEnableOption "automatic login without password prompt";
        username = lib.mkOption {
          type = lib.types.str;
          default = "User";
          description = "Windows username for automatic login";
        };
      };

      kiosk = {
        enable = lib.mkEnableOption "kiosk/appliance mode with auto-starting application";
        application = lib.mkOption {
          type = lib.types.enum [ "kodi" "jellyfin-mpv-shim" "custom" ];
          default = "kodi";
          description = "Application to auto-start. 'kodi' for Kodi media center.";
        };
        customCommand = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Custom command to run when application is set to 'custom'";
        };
        # TODO: Shell replacement mode - replace Explorer with Kodi entirely
        # shellReplacement = lib.mkOption {
        #   type = lib.types.bool;
        #   default = false;
        #   description = "Replace Windows Explorer with the kiosk application";
        # };
      };

      podmanSystemService = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Run Podman as a system service instead of user process.
          Containers will start at boot regardless of user login state.
          Recommended for server/appliance deployments.
        '';
      };
    };

    # =========================================================================
    # Kodi Media Center Configuration
    # =========================================================================
    kodi = {
      enable = lib.mkEnableOption "Kodi configuration management";

      jellyfin = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable Jellyfin integration via Jellyfin for Kodi add-on";
        };
        serverUrl = lib.mkOption {
          type = lib.types.str;
          description = "Jellyfin server URL (e.g., http://localhost:8096)";
          example = "http://jellyfin:8096";
        };
        syncMode = lib.mkOption {
          type = lib.types.enum [ "native" "addon" ];
          default = "native";
          description = ''
            Sync mode for Jellyfin:
            - native: Sync Jellyfin library to Kodi's native database (recommended)
            - addon: Browse Jellyfin through add-on interface only
          '';
        };
      };

      video = {
        resolution = lib.mkOption {
          type = lib.types.enum [ "1080p" "4k" ];
          default = "4k";
          description = "Maximum video resolution";
        };
        hdr = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable HDR passthrough";
        };
        refreshRateMatching = lib.mkOption {
          type = lib.types.enum [ "off" "start-stop" "always" ];
          default = "always";
          description = ''
            Adjust display refresh rate to match video:
            - off: Never adjust
            - start-stop: Adjust on start/stop
            - always: Always match content framerate
          '';
        };
      };

      audio = {
        passthrough = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable audio passthrough to receiver/TV";
        };
        formats = lib.mkOption {
          type = lib.types.listOf (lib.types.enum [
            "ac3" "eac3" "truehd" "dts" "dtshd"
          ]);
          default = [ "ac3" "eac3" "truehd" "dts" "dtshd" ];
          description = "Audio formats to passthrough (requires compatible receiver)";
        };
        atmos = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable Dolby Atmos passthrough";
        };
      };

      ui = {
        skin = lib.mkOption {
          type = lib.types.enum [
            "estuary"           # Default Kodi skin
            "arctic-horizon-2"  # Modern Netflix-style
            "arctic-zephyr-2"   # Clean minimalist
            "aeon-nox-silvo"    # Feature-rich
            "titan-bingie"      # Netflix/Disney+ style
          ];
          default = "arctic-horizon-2";
          description = "Kodi skin/theme";
        };
        startWindow = lib.mkOption {
          type = lib.types.enum [ "home" "movies" "tvshows" "music" "videos" ];
          default = "home";
          description = "Default window on startup";
        };
        screensaver = lib.mkOption {
          type = lib.types.str;
          default = "screensaver.xbmc.builtin.dim";
          description = "Screensaver to use";
        };
        screensaverTimeout = lib.mkOption {
          type = lib.types.int;
          default = 5;
          description = "Minutes before screensaver activates (0 = never)";
        };
      };

      performance = {
        bufferSize = lib.mkOption {
          type = lib.types.int;
          default = 104857600;  # 100MB
          description = "Video buffer size in bytes";
        };
        readFactor = lib.mkOption {
          type = lib.types.float;
          default = 8.0;
          description = "Read buffer factor (higher = more aggressive buffering)";
        };
      };
    };

    # =========================================================================
    # Rclone Cloud Storage Configuration
    # =========================================================================
    rclone = {
      enable = lib.mkEnableOption "rclone cloud storage integration";

      putio = {
        enable = lib.mkEnableOption "put.io remote storage";
        mountDrive = lib.mkOption {
          type = lib.types.str;
          default = "P";
          description = "Drive letter for put.io mount (e.g., P for P:\\)";
        };
        unionDrive = lib.mkOption {
          type = lib.types.str;
          default = "M";
          description = "Drive letter for union mount (local + remote merged)";
        };
      };

      sync = {
        enable = lib.mkEnableOption "automatic sync from cloud to local";
        destination = lib.mkOption {
          type = lib.types.str;
          default = "C:\\Media\\Cloud";
          description = "Local destination for synced files";
        };
        intervalMinutes = lib.mkOption {
          type = lib.types.int;
          default = 30;
          description = "Minutes between sync runs";
        };
        minAge = lib.mkOption {
          type = lib.types.str;
          default = "60m";
          description = "Minimum file age before syncing (prevents syncing incomplete uploads)";
        };
        deleteAfterSync = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Delete files from cloud after successful sync to local";
        };
      };
    };

    containers = lib.mkOption {
      type = lib.types.attrsOf containerOpts;
      default = {};
      description = "Container definitions";
    };

    # High-level service presets
    services = {
      jellyfin = {
        enable = lib.mkEnableOption "Jellyfin media server";
        gpu = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable GPU transcoding";
        };
      };

      arr = {
        enable = lib.mkEnableOption "arr stack (Radarr, Sonarr, etc.)";
        enableLidarr = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable Lidarr (music)";
        };
        enableReadarr = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable Readarr (books)";
        };
      };

      ollama = {
        enable = lib.mkEnableOption "Ollama LLM server";
        webui = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable Open WebUI";
        };
      };

      kanidm = {
        enable = lib.mkEnableOption "Kanidm identity provider";
      };

      watchtower = {
        enable = lib.mkEnableOption "Watchtower auto-updates";
        schedule = lib.mkOption {
          type = lib.types.str;
          default = "0 0 4 * * *";
          description = "Cron schedule for updates";
        };
      };
    };
  };

  # This module doesn't have a config section - it's evaluated by the flake
  # to generate the outputs. See flake.nix for how this is used.
}
