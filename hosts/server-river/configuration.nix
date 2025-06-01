{ config, pkgs, lib, inputs, ... }:

let
  vars = import ../../lib/vars.nix;
in {
  imports = [
    ./hardware-configuration.nix
    ../common/base.nix
    ../common/security.nix
    inputs.sops-nix.nixosModules.sops
  ];

  # SOPS secrets management
  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets = {
      # Certificate Authority
      ca-intermediate-passphrase = {
        owner = "step-ca";
        group = "step-ca";
        mode = "0400";
      };

      # ACME credentials
      cloudflare-api-key = {
        owner = "acme";
        group = "acme";
        mode = "0400";
      };

      # Backup encryption
      borg-passphrase = {
        owner = "root";
        group = "users";
        mode = "0400";
      };
      borg-passphrase-offline = {
        owner = "root";
        group = "users";
        mode = "0400";
      };

      # Backblaze B2
      backblaze-env = {
        owner = "root";
        group = "users";
        mode = "0400";
        format = "dotenv";
        sopsFile = ./secrets.yaml;
      };

      # Grafana
      grafana-admin-password = {
        owner = "grafana";
        group = "grafana";
        mode = "0400";
      };

      # Headscale
      headscale-private-key = {
        owner = "headscale";
        group = "headscale";
        mode = "0400";
      };
    };
  };

  networking.hostName = "server-river";
  networking.hostId = "12345678"; # Required for ZFS - generate with: head -c 8 /etc/machine-id
  networking.networkmanager.enable = true;

  # Headless server optimizations
  services.xserver.enable = false;
  services.desktopManager.cosmic.enable = lib.mkForce false;
  services.displayManager.cosmic-greeter.enable = lib.mkForce false;

  # Remove desktop environment variables (keep NIX_PATH for system functionality)
  environment.sessionVariables = lib.mkForce {
    NIX_PATH = lib.concatStringsSep ":" [
      "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
      "nixos-config=/etc/nixos/configuration.nix"
      "/nix/var/nix/profiles/per-user/root/channels"
    ];
  };

  # Modern server packages with ZFS and data management tools
  environment.systemPackages = with pkgs; [
    # Essential server tools
    htop btop curl wget tree
    # Network diagnostics
    dig nmap netcat-gnu
    # System monitoring
    lm_sensors smartmontools iotop
    # Container management
    podman-compose
    # ZFS management
    zfs zfs-prune-snapshots
    # Advanced file tools
    rsync rclone borgbackup
    # Cloud backup tools
    backblaze-b2 restic
    # VPN coordination server
    headscale
    # Data integrity
    par2cmdline ddrescue
    # Modern CLI tools
    fd ripgrep bat
    # Network file tools
    nfs-utils
    # TPM 2.0 tools
    tpm2-tools
    tpm2-tss
    tpm2-abrmd

    # Management scripts from external files
    (writeShellScriptBin "ca-install-from-airgap" (builtins.readFile ./scripts/ca-install-from-airgap.sh))
    (writeShellScriptBin "ca-status" (builtins.readFile ./scripts/ca-status.sh))
    (writeShellScriptBin "tmp-status" (builtins.readFile ./scripts/tpm-status.sh))
    (writeShellScriptBin "tpm-seal-ca-key" (builtins.readFile ./scripts/tpm-seal-ca-key.sh))
    (writeShellScriptBin "security-status" (builtins.readFile ./scripts/security-status.sh))
    (writeShellScriptBin "backup-validate" (builtins.readFile ./scripts/backup-validate.sh))
    (writeShellScriptBin "backup-restore-test" (builtins.readFile ./scripts/backup-restore-test.sh))
    (writeShellScriptBin "smart-notify" (builtins.readFile ./scripts/smart-notify.sh))
  ];

  # Container runtime for server applications
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    defaultNetwork.settings = {
      dns_enabled = true;
      ipv6_enabled = false;
    };
  };

  # Container registry mirrors
  virtualisation.containers.registries.search = [
    "docker.io"
    "quay.io"
    "ghcr.io"
  ];

  # Automatic cleanup
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  virtualisation.podman.autoPrune = {
    enable = true;
    dates = "weekly";
    flags = [ "--all" ];
  };

  # Server monitoring
  services.vnstat.enable = true;

  # Security auditing
  security.auditd.enable = true;

  # TPM 2.0 integration for CA key protection
  security.tpm2 = {
    enable = true;
    tssUser = "step-ca";
    abrmd.enable = true;  # TPM Access Broker & Resource Manager
  };

  # Enable TPM device access
  boot.kernelModules = [ "tpm_tis" "tpm_crb" ];
  services.udev.extraRules = ''
    # TPM device permissions for step-ca
    SUBSYSTEM=="tpm", GROUP="tss", MODE="0660"
    SUBSYSTEM=="tpmrm", GROUP="tss", MODE="0660"
  '';

  # No power management for server
  services.tlp.enable = false;
  services.power-profiles-daemon.enable = false;
  services.thermald.enable = false;

  # Server user groups and step-ca user
  users.users.${vars.user.name}.extraGroups = ["docker"];

  users.users.step-ca = {
    isSystemUser = true;
    group = "step-ca";
    extraGroups = [ "tss" ];  # TPM access
    home = "/var/lib/step-ca";
    createHome = true;
  };

  users.groups.step-ca = {};

  # Swap configuration
  swapDevices = [{
    device = vars.hosts."server-river".swapPath;
    size = vars.hosts."server-river".swapSize;
  }];

  # ZFS Configuration
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;
  services.zfs.autoScrub.enable = true;
  services.zfs.autoScrub.interval = "weekly";
  services.zfs.autoSnapshot.enable = true;
  services.zfs.autoSnapshot.flags = "-k -p --utc";

  # ZFS snapshot schedule
  services.zfs.autoSnapshot.frequent = 8;   # every 15min, keep 8 (2h)
  services.zfs.autoSnapshot.hourly = 48;    # keep 48 (2 days)
  services.zfs.autoSnapshot.daily = 14;     # keep 14 (2 weeks)
  services.zfs.autoSnapshot.weekly = 8;     # keep 8 (2 months)
  services.zfs.autoSnapshot.monthly = 12;   # keep 12 (1 year)

  # Advanced NFS Server with NFSv4.2
  services.nfs.server = {
    enable = true;

    # NFSv4 only for better security and performance
    nproc = 16;

    exports = ''
      # VPN-only NFS exports - restrict to Headscale network
      /tank/nfs            100.64.0.0/10(rw,sync,no_subtree_check,fsid=root,crossmnt,security=sys)
      /tank/nfs/share      100.64.0.0/10(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=100,security=sys)
      /tank/nfs/backup     100.64.0.0/10(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=100,security=sys)
      /tank/nfs/media      100.64.0.0/10(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=100,security=sys)
      /tank/nfs/documents  100.64.0.0/10(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=100,security=sys)
    '';
  };

  # NFS optimizations
  services.nfs.settings = {
    nfsd = {
      # NFSv4.2 enables advanced features like copy_file_range, fallocate
      "vers2" = "no";
      "vers3" = "no";
      "vers4" = "yes";
      "vers4.0" = "yes";
      "vers4.1" = "yes";
      "vers4.2" = "yes";
    };
  };

  # Create ZFS datasets and directories
  # Note: You'll need to create the ZFS pool manually:
  # zpool create -o ashift=12 -O compression=lz4 -O acltype=posixacl -O xattr=sa tank /dev/sdX
  systemd.tmpfiles.rules = [
    "d /tank/nfs 0755 root root -"
    "d /tank/nfs/share 0755 ${vars.user.name} users -"
    "d /tank/nfs/backup 0755 ${vars.user.name} users -"
    "d /tank/nfs/media 0755 ${vars.user.name} users -"
    "d /tank/nfs/documents 0755 ${vars.user.name} users -"
    "d /tank/syncthing 0755 ${vars.user.name} users -"
    # Backup infrastructure
    "d /mnt/backup-drive 0755 root root -"
    "d /var/log 0755 root root -"
    "f /var/log/backup-notifications.log 0644 ${vars.user.name} users -"
    "f /var/log/dashboard-events.log 0644 ${vars.user.name} users -"
    # Grafana dashboard directory
    "d /etc/grafana/dashboards 0755 root root -"
    "L+ /etc/grafana/dashboards/server-overview.json - - - - ${./dashboard-config.json}"
    # Headscale directories
    "d /var/lib/headscale 0750 headscale headscale -"
    # ACME certificate directories
    "d /var/lib/acme 0755 acme acme -"
    # Step-CA directories
    "d /etc/step-ca 0755 root root -"
    "d /etc/step-ca/certs 0755 root root -"
    "d /etc/step-ca/secrets 0700 step-ca step-ca -"
    "d /var/lib/step-ca 0755 step-ca step-ca -"
    "d /var/lib/step-ca/db 0700 step-ca step-ca -"
    # CA transfer staging area
    "d /tmp/ca-transfer 0700 root root -"
    # TPM directories
    "d /var/lib/step-ca/tmp 0700 step-ca step-ca -"
    "d /run/credentials/step-ca 0700 step-ca step-ca -"
    # Backup validation directories
    "d /var/lib/backup-validation 0755 root root -"
    "d /var/lib/backup-validation/test-restore 0755 root root -"
    "d /var/lib/backup-validation/reports 0755 root root -"
    "d /var/lib/backup-validation/checkpoints 0755 root root -"
  ];

  # Centralized logging with Loki + Promtail
  services.loki = {
    enable = true;

    configuration = {
      auth_enabled = false;

      server = {
        http_listen_address = "100.64.0.1";  # VPN-only
        http_listen_port = 3100;
        log_level = "info";
      };

      common = {
        path_prefix = "/var/lib/loki";
        storage.filesystem = {
          chunks_directory = "/var/lib/loki/chunks";
          rules_directory = "/var/lib/loki/rules";
        };
        replication_factor = 1;
        ring = {
          instance_addr = "100.64.0.1";
          kvstore.store = "inmemory";
        };
      };

      query_range.results_cache.cache.embedded_cache = {
        enabled = true;
        max_size_mb = 100;
      };

      schema_config.configs = [{
        from = "2024-01-01";
        store = "tsdb";
        object_store = "filesystem";
        schema = "v13";
        index = {
          prefix = "index_";
          period = "24h";
        };
      }];

      ruler.alertmanager_url = "http://100.64.0.1:9093";

      # Retention and limits
      limits_config = {
        retention_period = "30d";
        ingestion_rate_mb = 16;
        ingestion_burst_size_mb = 32;
        max_query_parallelism = 16;
        max_streams_per_user = 10000;
        max_line_size = "256KB";
        max_entries_limit_per_query = 5000;
      };

      table_manager = {
        retention_deletes_enabled = true;
        retention_period = "30d";
      };
    };
  };

  # Log shipping with Promtail
  services.promtail = {
    enable = true;

    configuration = {
      server = {
        http_listen_address = "100.64.0.1";
        http_listen_port = 9080;
      };

      clients = [{
        url = "http://100.64.0.1:3100/loki/api/v1/push";
      }];

      scrape_configs = [
        {
          job_name = "systemd-journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = "server-river";
            };
          };
          relabel_configs = [
            {
              source_labels = [ "__journal__systemd_unit" ];
              target_label = "unit";
            }
            {
              source_labels = [ "__journal_priority" ];
              target_label = "priority";
            }
            {
              source_labels = [ "__journal__hostname" ];
              target_label = "hostname";
            }
          ];
        }

        {
          job_name = "step-ca-logs";
          static_configs = [{
            targets = [ "localhost" ];
            labels = {
              job = "step-ca";
              host = "server-river";
              service = "certificate-authority";
              __path__ = "/var/log/step-ca/*.log";
            };
          }];
          pipeline_stages = [
            {
              match = {
                selector = ''{job="step-ca"}'';
                stages = [
                  {
                    regex = {
                      expression = ''(?P<timestamp>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})\s+(?P<level>\w+)\s+(?P<message>.*)'';
                    };
                  }
                  {
                    labels = {
                      level = "";
                    };
                  }
                ];
              };
            }
          ];
        }

        {
          job_name = "nginx-access";
          static_configs = [{
            targets = [ "localhost" ];
            labels = {
              job = "nginx";
              host = "server-river";
              log_type = "access";
              __path__ = "/var/log/nginx/access.log";
            };
          }];
          pipeline_stages = [
            {
              regex = {
                expression = ''(?P<remote_addr>[\d\.]+) - (?P<remote_user>\S+) \[(?P<time_local>[^\]]+)\] "(?P<method>\S+) (?P<request_uri>\S+) (?P<server_protocol>\S+)" (?P<status>\d+) (?P<body_bytes_sent>\d+) "(?P<http_referer>[^"]*)" "(?P<http_user_agent>[^"]*)"'';
              };
            }
            {
              labels = {
                method = "";
                status = "";
              };
            }
          ];
        }

        {
          job_name = "nginx-error";
          static_configs = [{
            targets = [ "localhost" ];
            labels = {
              job = "nginx";
              host = "server-river";
              log_type = "error";
              __path__ = "/var/log/nginx/error.log";
            };
          }];
        }

        {
          job_name = "backup-logs";
          static_configs = [{
            targets = [ "localhost" ];
            labels = {
              job = "backup";
              host = "server-river";
              __path__ = "/var/log/backup-notifications.log";
            };
          }];
          pipeline_stages = [
            {
              match = {
                selector = ''{job="backup"}'';
                stages = [
                  {
                    regex = {
                      expression = ''(?P<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s+(?P<backup_type>\w+)\s+backup\s+(?P<status>\w+)'';
                    };
                  }
                  {
                    labels = {
                      backup_type = "";
                      status = "";
                    };
                  }
                ];
              };
            }
          ];
        }

        {
          job_name = "security-logs";
          static_configs = [{
            targets = [ "localhost" ];
            labels = {
              job = "security";
              host = "server-river";
              __path__ = "/var/log/auth.log";
            };
          }];
          pipeline_stages = [
            {
              match = {
                selector = ''{job="security"} |~ "FAILED|ERROR|DENIED"'';
                stages = [
                  {
                    labels = {
                      alert_level = "warning";
                    };
                  }
                ];
              };
            }
          ];
        }
      ];
    };
  };

  # Enhanced Syncthing on ZFS (VPN-only)
  services.syncthing = {
    enable = true;
    user = vars.user.name;
    dataDir = "/tank/syncthing";
    configDir = "/home/${vars.user.name}/.config/syncthing";

    settings = {
      gui = {
        address = "100.64.0.1:8384";  # Bind to VPN interface only
        insecureAdminAccess = false;
        theme = "dark";
      };
      options = {
        globalAnnounceEnabled = true;
        localAnnounceEnabled = true;
        relaysEnabled = true;
        natEnabled = true;
        urAccepted = -1; # Disable usage reporting
        # Enhanced performance settings
        maxSendKbps = 0; # Unlimited
        maxRecvKbps = 0; # Unlimited
        reconnectionIntervalS = 60;
        startBrowser = false;
      };
    };
  };

  # Multi-tier backup strategy: Local → Cloud → Offline

  # 1. Local Borg backup (fastest recovery)
  services.borgbackup.jobs = {
    "tank-local" = {
      paths = [ "/tank/nfs" ];
      repo = "/tank/nfs/backup/borg-local";
      compression = "zstd,3";
      startAt = "daily";
      user = vars.user.name;
      group = "users";

      encryption = {
        mode = "repokey";
        passCommand = "cat ${config.sops.secrets.borg-passphrase.path}";
      };

      prune.keep = {
        daily = 7;
        weekly = 4;
        monthly = 6;
        yearly = 2;
      };

      postHook = ''
        echo "Local backup completed at $(date)" >> /var/log/backup-notifications.log

        # Dashboard-only success notification (no push)
        smart-notify info "Daily Backup" "Local backup completed successfully" "backup,daily"
      '';

    };

    # 2. Offline drive backup (weekly rotation)
    "tank-offline" = {
      paths = [ "/tank/nfs" ];
      repo = "/mnt/backup-drive/borg-offline";
      compression = "zstd,3";
      startAt = "weekly";
      user = vars.user.name;
      group = "users";

      encryption = {
        mode = "repokey";
        passCommand = "cat ${config.sops.secrets.borg-passphrase-offline.path}";
      };

      # Only run if backup drive is mounted
      preHook = ''
        if ! mountpoint -q /mnt/backup-drive; then
          echo "Backup drive not mounted, skipping offline backup"
          exit 0
        fi
        echo "Starting offline backup to $(lsblk -no MODEL /mnt/backup-drive)"
      '';

      postHook = ''
        echo "Offline backup completed successfully"
        echo "Offline backup completed at $(date)" >> /var/log/backup-notifications.log

        # Weekly offline backup success - work hours notification
        smart-notify warning "Offline Backup Complete" "Weekly backup to external drive completed successfully" "backup,offline"
      '';

      prune.keep = {
        daily = 14;   # Keep more on offline drives
        weekly = 8;
        monthly = 12;
        yearly = 5;
      };
    };
  };

  # 3. Backblaze B2 cloud backup (automated offsite)
  systemd.services."backblaze-backup" = {
    description = "Backblaze B2 cloud backup";
    serviceConfig = {
      Type = "oneshot";
      User = vars.user.name;
      Group = "users";
      EnvironmentFile = config.sops.secrets.backblaze-env.path;
    };

    script = ''
      # Sync to Backblaze B2 using rclone
      ${pkgs.rclone}/bin/rclone sync /tank/nfs/share b2:server-river-backup/share \
        --progress \
        --transfers 4 \
        --checkers 8 \
        --fast-list \
        --exclude ".zfs/**" \
        --exclude "**/.stfolder" \
        --exclude "**/.stignore" \
        --log-file /var/log/backblaze-backup.log \
        --log-level INFO

      # Also backup critical system configs
      ${pkgs.rclone}/bin/rclone sync /home/${vars.user.name}/.config/syncthing b2:server-river-backup/configs/syncthing \
        --log-file /var/log/backblaze-backup.log \
        --log-level INFO

      echo "Backblaze backup completed at $(date)" >> /var/log/backup-notifications.log

      # Dashboard-only success (no push for daily cloud backups)
      smart-notify info "Cloud Backup" "Backblaze B2 sync completed successfully" "backup,cloud"
    '';
  };

  systemd.timers."backblaze-backup" = {
    description = "Backblaze B2 backup timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "2h";  # Spread load
    };
  };

  # Smart monitoring for drives
  services.smartd = {
    enable = true;
    autodetect = true;
    notifications = {
      mail.enable = false;
      wall.enable = true;
    };
  };

  # Firewall configuration for VPN-only services
  networking.firewall = {
    # Public access: HTTPS (nginx/ACME) and SSH only
    allowedTCPPorts = [ 80 443 ];  # HTTP/HTTPS for Let's Encrypt and Headscale
    allowedUDPPorts = [ ];

    # VPN interface rules - allow admin services on Headscale network only
    interfaces."tailscale0" = {
      allowedTCPPorts = [
        2049    # NFS
        111     # RPC portmapper
        3000    # Grafana
        3100    # Loki
        8080    # ntfy
        8384    # Syncthing
        9080    # Promtail
        9090    # Prometheus
        9093    # Alertmanager
        9100    # Node exporter
        9115    # Blackbox exporter
      ];
      allowedUDPPorts = [
        2049    # NFS
        111     # RPC portmapper
      ];
    };
  };

  # RPC services required for NFS
  services.rpcbind.enable = true;

  # ZFS monitoring and alerting (ZED not available in this NixOS version)

  # Periodic data integrity checks
  systemd.services."zfs-monthly-scrub" = {
    description = "Monthly ZFS scrub";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.zfs}/bin/zpool scrub tank";
    };
  };

  systemd.timers."zfs-monthly-scrub" = {
    description = "Monthly ZFS scrub timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "monthly";
      Persistent = true;
    };
  };

  # Comprehensive monitoring stack (VPN-only)
  services.prometheus = {
    enable = true;
    port = 9090;
    listenAddress = "100.64.0.1";  # Bind to VPN interface only

    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" "zfs" "filesystem" "diskstats" "meminfo" ];
        port = 9100;
      };

      # SSL certificate monitoring
      blackbox = {
        enable = true;
        port = 9115;
        configFile = pkgs.writeText "blackbox.yml" ''
          modules:
            http_2xx:
              prober: http
              timeout: 5s
              http:
                valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
                valid_status_codes: []
                method: GET
                headers:
                  Host: sync.robcohen.dev
                  Accept-Language: en-US
                fail_if_ssl: false
                fail_if_not_ssl: true
                tls_config:
                  insecure_skip_verify: false
            tcp_connect:
              prober: tcp
              timeout: 5s
        '';
      };

      # Custom backup status exporter (configured via Prometheus target)
      json = {
        enable = true;
        port = 9105;
        configFile = pkgs.writeText "json-exporter-config.yml" ''
          modules:
            default:
              metrics:
              - name: backup_validation_success
                path: $.validation_success
                type: gauge
        '';
      };
    };

    rules = [
      # Enhanced monitoring rules with certificate expiry
      ''
        groups:
        - name: backup_alerts
          rules:
          - alert: BackupJobFailed
            expr: increase(backup_job_failures_total[1h]) > 0
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "Backup job {{ $labels.job }} failed"
              description: "Backup job {{ $labels.job }} has failed in the last hour"

          - alert: BackupJobMissing
            expr: (time() - backup_last_success_timestamp) > 86400
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "Backup job {{ $labels.job }} hasn't run in 24h"

        - name: infrastructure_alerts
          rules:
          - alert: ZFSPoolDegraded
            expr: zfs_pool_health != 0
            for: 1m
            labels:
              severity: critical
            annotations:
              summary: "ZFS pool {{ $labels.pool }} is degraded"

          - alert: DiskSpaceHigh
            expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) < 0.1
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "Disk space low on {{ $labels.mountpoint }}"

        - name: security_alerts
          rules:
          - alert: CertificateExpiringSoon
            expr: (probe_ssl_earliest_cert_expiry - time()) / 86400 < 30
            for: 1h
            labels:
              severity: warning
            annotations:
              summary: "Certificate expiring soon"
              description: "Certificate for {{ $labels.instance }} expires in {{ $value }} days"

          - alert: CertificateExpiredOrInvalid
            expr: probe_ssl_earliest_cert_expiry - time() <= 0
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "Certificate expired or invalid"
              description: "Certificate for {{ $labels.instance }} has expired or is invalid"

          - alert: StepCADown
            expr: up{job="step-ca"} == 0
            for: 2m
            labels:
              severity: critical
            annotations:
              summary: "Step-CA service is down"
              description: "Internal certificate authority is not responding"

          - alert: SystemdServiceFailed
            expr: node_systemd_unit_state{state="failed"} == 1
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "Systemd service {{ $labels.name }} failed"
              description: "Service {{ $labels.name }} is in failed state"

        - name: performance_alerts
          rules:
          - alert: HighCPUUsage
            expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "High CPU usage"
              description: "CPU usage is above 80% for more than 10 minutes"

          - alert: HighMemoryUsage
            expr: (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 90
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "High memory usage"
              description: "Memory usage is above 90%"

        - name: backup_validation_alerts
          rules:
          - alert: BackupValidationFailed
            expr: backup_validation_success == 0
            for: 1m
            labels:
              severity: critical
            annotations:
              summary: "Backup validation failed"
              description: "Backup validation for {{ $labels.backup_type }} failed. Check /var/lib/backup-validation/reports/ for details"

          - alert: BackupValidationOverdue
            expr: time() - backup_validation_last_run > 7862400  # 91 days (quarterly + 1 day grace)
            for: 1h
            labels:
              severity: warning
            annotations:
              summary: "Backup validation overdue"
              description: "Backup validation hasn't run in over 91 days. Scheduled quarterly validation may have failed"

          - alert: BackupRestoreTestFailed
            expr: backup_restore_test_success == 0
            for: 1m
            labels:
              severity: critical
            annotations:
              summary: "Backup restore test failed"
              description: "Restore test for {{ $labels.backup_type }} failed. Backup integrity compromised"

          - alert: DisasterRecoverySimulationFailed
            expr: disaster_recovery_simulation_success == 0
            for: 1m
            labels:
              severity: critical
            annotations:
              summary: "Disaster recovery simulation failed"
              description: "Disaster recovery simulation failed. Review backup strategy and restore procedures"
      ''
    ];

    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [{ targets = [ "localhost:9100" ]; }];
        scrape_interval = "15s";
      }
      {
        job_name = "backup-status";
        static_configs = [{ targets = [ "localhost:9105" ]; }];
        scrape_interval = "60s";
      }
      {
        job_name = "backup-validation";
        static_configs = [{ targets = [ "localhost:9106" ]; }];
        scrape_interval = "300s";  # Check every 5 minutes
      }
      {
        job_name = "step-ca";
        static_configs = [{ targets = [ "localhost:9000" ]; }];
        scrape_interval = "30s";
        metrics_path = "/health";
      }
      {
        job_name = "ssl-certificates";
        static_configs = [
          {
            targets = [
              "sync.robcohen.dev:443"
              "grafana.internal.robcohen.dev:3000"
              "notify.internal.robcohen.dev:8080"
            ];
          }
        ];
        scrape_interval = "300s";  # Check every 5 minutes
        metrics_path = "/probe";
        params = {
          module = [ "http_2xx" ];
        };
        relabel_configs = [
          {
            source_labels = [ "__address__" ];
            target_label = "__param_target";
          }
          {
            source_labels = [ "__param_target" ];
            target_label = "instance";
          }
          {
            target_label = "__address__";
            replacement = "localhost:9115";  # Blackbox exporter
          }
        ];
      }
    ];

    alertmanager = {
      enable = true;
      port = 9093;
      listenAddress = "100.64.0.1";  # Bind to VPN interface only

      configuration = {
        global = {
          smtp_smarthost = "localhost:587";
        };

        route = {
          group_by = [ "alertname" ];
          group_wait = "30s";
          group_interval = "5m";
          repeat_interval = "12h";
          receiver = "ntfy-alerts";
        };

        receivers = [
          {
            name = "ntfy-alerts";
            webhook_configs = [
              {
                url = "http://100.64.0.1:8081/webhook";
                send_resolved = true;
              }
            ];
          }
        ];
      };
    };
  };

  # Grafana dashboard
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "100.64.0.1";  # Bind to VPN interface only
        http_port = 3000;
        domain = "grafana.internal.robcohen.dev";
      };

      security = {
        admin_user = "admin";
        admin_password = "$__file{${config.sops.secrets.grafana-admin-password.path}}";
      };

      database = {
        type = "sqlite3";
        path = "/var/lib/grafana/grafana.db";
      };
    };

    provision = {
      enable = true;

      datasources.settings = {
        apiVersion = 1;
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://100.64.0.1:9090";
            isDefault = true;
          }
          {
            name = "Loki";
            type = "loki";
            access = "proxy";
            url = "http://100.64.0.1:3100";
          }
        ];
      };

      dashboards.settings = {
        apiVersion = 1;
        providers = [
          {
            name = "server-river-dashboards";
            type = "file";
            options.path = "/etc/grafana/dashboards";
            disableDeletion = true;
          }
        ];
      };
    };
  };

  # Smart ntfy notification routing
  services.ntfy-sh = {
    enable = true;
    settings = {
      listen-http = "100.64.0.1:8080";  # Bind to VPN interface only
      behind-proxy = false;
      base-url = "http://notify.internal.robcohen.dev:8080";

      # Authentication
      auth-default-access = "deny-all";
      auth-file = "/var/lib/ntfy-sh/users.db";

      # Retention by topic
      keep-unconfirmed = "12h";
      keep-confirmed = "30d";

      # File uploads for reports
      attachment-cache-dir = "/var/lib/ntfy-sh/attachments";
      attachment-total-size-limit = "100M";
    };
  };
  # Weekly summary report

  # Step-CA for internal service certificates (using intermediate from air-gap)
  services.step-ca = {
    enable = true;
    address = "127.0.0.1";
    port = 9000;
    intermediatePasswordFile = config.sops.secrets.ca-intermediate-passphrase.path;

    settings = {
      root = "/etc/step-ca/certs/root_ca.crt";
      crt = "/etc/step-ca/certs/intermediate_ca.crt";
      key = "/run/credentials/step-ca/ca-key";  # TPM-unsealed key

      dnsNames = [ "step-ca.internal.robcohen.dev" "localhost" ];

      logger = {
        format = "text";
      };

      db = {
        type = "badgerv2";
        dataSource = "/var/lib/step-ca/db";
      };

      authority = {
        provisioners = [
          {
            type = "ACME";
            name = "internal-acme";
            claims = {
              defaultTLSCertDuration = "2160h";     # 90 days
              maxTLSCertDuration = "8760h";        # 1 year
              minTLSCertDuration = "24h";          # 1 day
            };
          }
          {
            type = "JWK";
            name = "admin";
            key = {
              use = "sig";
              kty = "EC";
              kid = "admin";
              crv = "P-256";
              alg = "ES256";
            };
            encryptedKey = "eyJhbGciOiJQQkVTMi1IUzI1NitBMTI4S1ciLCJjdHkiOiJqd2sranNvbiIsImVuYyI6IkEyNTZHQ00iLCJwMmMiOjEwMDAwMCwicDJzIjoiZjVvdGVRS2hvOXl4MmQtSGlIX1dHQSJ9";
          }
        ];
      };

      tls = {
        cipherSuites = [
          "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256"
          "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"
        ];
        minVersion = 1.2;
        maxVersion = 1.3;
        renegotiation = false;
      };
    };
  };

  # TPM-backed step-ca service configuration with security hardening
  systemd.services.step-ca = {
    preStart = ''
      # Ensure TPM is available
      if [ ! -c /dev/tpm0 ] && [ ! -c /dev/tpmrm0 ]; then
        echo "⚠️  TPM device not found - using filesystem CA key"
        if [ -f /etc/step-ca/secrets/intermediate_ca_key ]; then
          cp /etc/step-ca/secrets/intermediate_ca_key /run/credentials/step-ca/ca-key
          chmod 600 /run/credentials/step-ca/ca-key
          chown step-ca:step-ca /run/credentials/step-ca/ca-key
        fi
        exit 0
      fi

      # Try to unseal CA key from TPM
      if [ -f /var/lib/step-ca/tpm/ca-key.ctx ]; then
        echo "🔓 Attempting to unseal CA key from TPM..."
        if tpm2_unseal -c /var/lib/step-ca/tpm/ca-key.ctx -o /run/credentials/step-ca/ca-key 2>/dev/null; then
          echo "✅ CA key unsealed from TPM"
          chmod 600 /run/credentials/step-ca/ca-key
          chown step-ca:step-ca /run/credentials/step-ca/ca-key
        else
          echo "⚠️  Failed to unseal from TPM - using filesystem key"
          if [ -f /etc/step-ca/secrets/intermediate_ca_key ]; then
            cp /etc/step-ca/secrets/intermediate_ca_key /run/credentials/step-ca/ca-key
            chmod 600 /run/credentials/step-ca/ca-key
            chown step-ca:step-ca /run/credentials/step-ca/ca-key
          else
            echo "❌ No CA key available"
            exit 1
          fi
        fi
      else
        echo "⚠️  No sealed key found - using filesystem key"
        if [ -f /etc/step-ca/secrets/intermediate_ca_key ]; then
          cp /etc/step-ca/secrets/intermediate_ca_key /run/credentials/step-ca/ca-key
          chmod 600 /run/credentials/step-ca/ca-key
          chown step-ca:step-ca /run/credentials/step-ca/ca-key
        else
          echo "❌ No CA key available"
          exit 1
        fi
      fi
    '';

    postStop = ''
      # Securely remove unsealed key
      if [ -f /run/credentials/step-ca/ca-key ]; then
        shred -vfz -n 3 /run/credentials/step-ca/ca-key || rm -f /run/credentials/step-ca/ca-key
      fi
    '';

    serviceConfig = {
      # Ensure proper TPM access
      SupplementaryGroups = [ "tss" ];
      # Dynamic credentials directory
      LoadCredential = [];

      # Security hardening
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = false;  # Need TPM access
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      RemoveIPC = true;
      RestrictRealtime = true;
      RestrictNamespaces = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      SystemCallFilter = [ "@system-service" "~@debug" "~@mount" "~@privileged" ];
      SystemCallArchitectures = "native";

      # Network restrictions
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];

      # File system restrictions
      ReadWritePaths = [ "/var/lib/step-ca" "/run/credentials/step-ca" ];
      ReadOnlyPaths = [ "/etc/step-ca" ];
    };
  };

  # Security hardening for critical services
  # Note: Grafana, Prometheus, Loki, ntfy-sh, Promtail, and Headscale use their respective module defaults
  # Custom hardening removed due to conflicts with NixOS module security configurations

  # TPM PCR monitoring service
  systemd.services."tpm-pcr-monitor" = {
    description = "TPM PCR integrity monitoring";
    serviceConfig = {
      Type = "oneshot";
      User = "step-ca";
      Group = "step-ca";
      ExecStart = "${pkgs.writeShellScript "tpm-pcr-monitor" ''
        #!/usr/bin/env bash
        set -euo pipefail

        # Skip if no TPM
        if [ ! -c /dev/tpm0 ] && [ ! -c /dev/tpmrm0 ]; then
          echo "No TPM device found, skipping PCR monitoring"
          exit 0
        fi

        BASELINE_FILE="/var/lib/step-ca/tpm/pcr.baseline"
        CURRENT_FILE="/tmp/pcr.current"

        # Read current PCR values
        ${pkgs.tpm2-tools}/bin/tpm2_pcrread sha256:0,1,2,3,4,5,6,7 > "$CURRENT_FILE"

        if [ -f "$BASELINE_FILE" ]; then
          if diff -q "$BASELINE_FILE" "$CURRENT_FILE" > /dev/null; then
            echo "✅ PCR values unchanged - system integrity verified"
          else
            echo "⚠️  PCR values have changed!"
            echo "📊 Changes detected:"
            diff "$BASELINE_FILE" "$CURRENT_FILE" || true

            # Send alert
            ${pkgs.curl}/bin/curl -d "System boot measurements changed - firmware/kernel update or potential compromise detected" \
              -H "Title: ⚠️ TPM PCR Changed" \
              -H "Priority: 4" \
              -H "Tags: warning,tpm,security" \
              "http://100.64.0.1:8080/server-warning" || true
          fi
        else
          echo "📝 Creating PCR baseline"
          cp "$CURRENT_FILE" "$BASELINE_FILE"
          chown step-ca:step-ca "$BASELINE_FILE"
        fi

        rm -f "$CURRENT_FILE"
      ''}";
    };
  };

  systemd.timers."tpm-pcr-monitor" = {
    description = "TPM PCR monitoring timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      Persistent = true;
    };
  };

  # Automated backup validation services
  systemd.services."backup-validation" = {
    description = "Automated backup validation and disaster recovery testing";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      ExecStart = "${pkgs.writeShellScript "backup-validation-automated" ''
        #!/usr/bin/env bash
        set -euo pipefail

        echo "🔍 Starting automated backup validation..."

        # Run validation suite
        if backup-validate; then
          echo "✅ Backup validation passed"
        else
          echo "❌ Backup validation failed"
          exit 1
        fi

        # Run sample restore test
        echo "🔄 Running sample restore test..."
        backup-restore-test local "tank/nfs/share" || true

        echo "✅ Automated backup validation complete"
      ''}";
    };
  };

  systemd.timers."backup-validation" = {
    description = "Quarterly backup validation timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "quarterly";  # Every 3 months
      Persistent = true;
      RandomizedDelaySec = "1h";  # Spread load
    };
  };

  # Backup validation metrics exporter
  systemd.services."backup-validation-metrics" = {
    description = "Backup validation metrics exporter";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "simple";
      User = "prometheus";
      Group = "prometheus";
      Restart = "always";
      RestartSec = "10s";
      ExecStart = "${pkgs.writeShellScript "backup-validation-metrics" ''
        #!/usr/bin/env bash
        set -euo pipefail

        METRICS_PORT=9106
        VALIDATION_DIR="/var/lib/backup-validation"
        REPORTS_DIR="$VALIDATION_DIR/reports"

        # Function to generate backup validation metrics
        generate_backup_metrics() {
          echo "# HELP backup_validation_success Last backup validation success status (1=success, 0=failure)"
          echo "# TYPE backup_validation_success gauge"

          echo "# HELP backup_validation_last_run Timestamp of last backup validation run"
          echo "# TYPE backup_validation_last_run gauge"

          echo "# HELP backup_restore_test_success Last backup restore test success status (1=success, 0=failure)"
          echo "# TYPE backup_restore_test_success gauge"

          echo "# HELP disaster_recovery_simulation_success Last disaster recovery simulation success status (1=success, 0=failure)"
          echo "# TYPE disaster_recovery_simulation_success gauge"

          # Check for latest validation report
          if [[ -d "$REPORTS_DIR" ]]; then
            LATEST_REPORT=$(ls -t "$REPORTS_DIR"/backup-validation-*.json 2>/dev/null | head -1)

            if [[ -n "$LATEST_REPORT" && -f "$LATEST_REPORT" ]]; then
              # Parse JSON report for validation status
              VALIDATION_SUCCESS=$(${pkgs.jq}/bin/jq -r '.overall_result == "PASS"' "$LATEST_REPORT" 2>/dev/null || echo "false")
              VALIDATION_TIMESTAMP=$(${pkgs.jq}/bin/jq -r '.validation_end_time // 0' "$LATEST_REPORT" 2>/dev/null || echo "0")
              RESTORE_SUCCESS=$(${pkgs.jq}/bin/jq -r '.tests.restore_test.result == "PASS"' "$LATEST_REPORT" 2>/dev/null || echo "false")
              DISASTER_SUCCESS=$(${pkgs.jq}/bin/jq -r '.tests.disaster_recovery.result == "PASS"' "$LATEST_REPORT" 2>/dev/null || echo "false")

              # Convert boolean to numeric
              [[ "$VALIDATION_SUCCESS" == "true" ]] && VALIDATION_SUCCESS=1 || VALIDATION_SUCCESS=0
              [[ "$RESTORE_SUCCESS" == "true" ]] && RESTORE_SUCCESS=1 || RESTORE_SUCCESS=0
              [[ "$DISASTER_SUCCESS" == "true" ]] && DISASTER_SUCCESS=1 || DISASTER_SUCCESS=0

              echo "backup_validation_success $VALIDATION_SUCCESS"
              echo "backup_validation_last_run $VALIDATION_TIMESTAMP"
              echo "backup_restore_test_success $RESTORE_SUCCESS"
              echo "disaster_recovery_simulation_success $DISASTER_SUCCESS"
            else
              # No reports found - default to 0
              echo "backup_validation_success 0"
              echo "backup_validation_last_run 0"
              echo "backup_restore_test_success 0"
              echo "disaster_recovery_simulation_success 0"
            fi
          else
            # Directory doesn't exist - default to 0
            echo "backup_validation_success 0"
            echo "backup_validation_last_run 0"
            echo "backup_restore_test_success 0"
            echo "disaster_recovery_simulation_success 0"
          fi
        }

        # Main HTTP server loop
        while true; do
          echo "Starting backup validation metrics server on port $METRICS_PORT..."

          # Generate metrics and serve via netcat
          {
            echo "HTTP/1.1 200 OK"
            echo "Content-Type: text/plain; version=0.0.4; charset=utf-8"
            echo ""
            generate_backup_metrics
          } | ${pkgs.netcat}/bin/nc -l -p $METRICS_PORT -q 1

          # Brief pause before restarting server
          sleep 1
        done
      ''}";
    };
  };


  # Let's Encrypt for public domain (sync.robcohen.dev)
  security.acme = {
    acceptTerms = true;
    defaults.email = vars.user.email;

    certs."sync.robcohen.dev" = {
      domain = "sync.robcohen.dev";
      dnsProvider = "cloudflare";
      environmentFile = config.sops.secrets.cloudflare-api-key.path;
      group = "nginx";
      postRun = "systemctl reload nginx";
      webroot = null; # Use DNS challenge, not webroot
    };
  };

  # Nginx reverse proxy with SSL termination
  services.nginx = {
    enable = true;

    virtualHosts."sync.robcohen.dev" = {
      enableACME = true;
      forceSSL = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:8085";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };

  # Headscale VPN coordination server (behind nginx)
  services.headscale = {
    enable = true;
    address = "127.0.0.1";  # Only listen locally, nginx handles SSL
    port = 8085;

    settings = {
      server_url = "https://sync.robcohen.dev";
      listen_addr = "127.0.0.1:8085";
      metrics_listen_addr = "127.0.0.1:9090";

      # IP ranges for the VPN network
      ip_prefixes = [
        "100.64.0.0/10"  # Standard Tailscale range
      ];

      # Database
      database = {
        type = "sqlite3";
        sqlite = {
          path = "/var/lib/headscale/db.sqlite";
        };
      };

      # Logging
      log = {
        level = "info";
        format = "text";
      };

      # DNS settings
      dns = {
        magic_dns = true;
        base_domain = "internal.robcohen.dev";
        nameservers = {
          global = [
            "1.1.1.1"
            "8.8.8.8"
          ];
        };
        search_domains = [ ];
      };

      # Disable Tailscale's default DERP servers (optional)
      derp = {
        server = {
          enabled = false;
        };
        urls = [ ];
        paths = [ ];
        auto_update_enabled = false;
        update_frequency = "24h";
      };

      # Ephemeral node inactivity timeout
      ephemeral_node_inactivity_timeout = "30m";
      node_update_check_interval = "10s";

      # API keys and authentication
      private_key_path = "/var/lib/headscale/private.key";
      noise = {
        private_key_path = "/var/lib/headscale/noise_private.key";
      };

      # Prefixes assigned to users
      prefixes = {
        v4 = "100.64.0.0/10";
        v6 = "fd7a:115c:a1e0::/48";
      };
    };
  };


  # Add headscale monitoring to notification system
  systemd.services."headscale-health-check" = {
    description = "Headscale health monitoring";
    serviceConfig = {
      Type = "oneshot";
      User = vars.user.name;
      Group = "users";
    };

    script = ''
      # Check if headscale is responding
      if ! curl -s http://100.64.0.1:8085/health > /dev/null; then
        smart-notify critical "VPN Coordination Down" "Network coordination server is not responding" "vpn,sync"
      fi

      # Check number of connected nodes
      NODE_COUNT=$(headscale nodes list | wc -l)
      echo "$(date): Headscale nodes connected: $NODE_COUNT" >> /var/log/dashboard-events.log
    '';
  };

  systemd.timers."headscale-health-check" = {
    description = "Headscale health check timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };
}
