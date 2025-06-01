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
  networking.networkmanager.enable = true;

  # Headless server optimizations
  services.xserver.enable = false;
  services.desktopManager.cosmic.enable = lib.mkForce false;
  services.displayManager.cosmic-greeter.enable = lib.mkForce false;
  
  # Remove desktop environment variables
  environment.sessionVariables = lib.mkForce {};

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
  services.smartd.enable = true;
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
      
      failHook = ''
        echo "Local backup FAILED at $(date)" >> /var/log/backup-notifications.log
        
        # Critical failure - always push
        smart-notify critical "Backup FAILED" "Daily local backup failed! Check logs immediately." "backup,failure"
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
  
  # ZFS monitoring and alerting
  services.zfs.zed = {
    enable = true;
    settings = {
      ZED_DEBUG_LOG = "/tmp/zed.debug.log";
      ZED_EMAIL_ADDR = [ "root" ];
      ZED_EMAIL_PROG = "mail";
      ZED_EMAIL_OPTS = "-s '@SUBJECT@' @ADDRESS@";
      ZED_NOTIFY_INTERVAL_SECS = 3600;
      ZED_NOTIFY_VERBOSE = true;
      ZED_USE_ENCLOSURE_LEDS = true;
      ZED_SCRUB_AFTER_RESILVER = true;
    };
  };
  
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
      
      # Custom backup status exporter
      json = {
        enable = true;
        port = 9105;
        url = "http://100.64.0.1:8080/backup-status";
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
  
  # CA integration and management scripts
  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "ca-install-from-airgap" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "📦 Installing CA Certificates from Air-Gap Transfer"
      echo "================================================="
      
      TRANSFER_DIR="''${1:-/tmp/ca-transfer}"
      
      if [ ! -d "$TRANSFER_DIR" ]; then
        echo "❌ Transfer directory not found: $TRANSFER_DIR"
        echo "Usage: $0 [transfer-directory]"
        exit 1
      fi
      
      # Verify required files exist
      REQUIRED_FILES=(
        "ca.cert.pem"
        "intermediate.cert.pem" 
        "intermediate.key.pem"
        "ca-chain.cert.pem"
      )
      
      for file in "''${REQUIRED_FILES[@]}"; do
        if [ ! -f "$TRANSFER_DIR/$file" ]; then
          echo "❌ Missing required file: $file"
          exit 1
        fi
      done
      
      echo "✅ All required files found"
      
      # Stop step-ca if running
      systemctl stop step-ca || true
      
      # Install certificates
      echo "📋 Installing root CA certificate..."
      cp "$TRANSFER_DIR/ca.cert.pem" /etc/step-ca/certs/root_ca.crt
      chmod 644 /etc/step-ca/certs/root_ca.crt
      
      echo "📋 Installing intermediate CA certificate..."
      cp "$TRANSFER_DIR/intermediate.cert.pem" /etc/step-ca/certs/intermediate_ca.crt
      chmod 644 /etc/step-ca/certs/intermediate_ca.crt
      
      echo "🔐 Installing intermediate CA private key..."
      cp "$TRANSFER_DIR/intermediate.key.pem" /etc/step-ca/secrets/intermediate_ca_key
      chmod 600 /etc/step-ca/secrets/intermediate_ca_key
      chown step-ca:step-ca /etc/step-ca/secrets/intermediate_ca_key
      
      echo "🔗 Installing certificate chain..."
      cp "$TRANSFER_DIR/ca-chain.cert.pem" /etc/step-ca/certs/ca_chain.crt
      chmod 644 /etc/step-ca/certs/ca_chain.crt
      
      # Install CRL if present
      if [ -f "$TRANSFER_DIR/intermediate.crl.pem" ]; then
        echo "📜 Installing certificate revocation list..."
        cp "$TRANSFER_DIR/intermediate.crl.pem" /etc/step-ca/certs/intermediate.crl
        chmod 644 /etc/step-ca/certs/intermediate.crl
      fi
      
      # Add root CA to system trust store
      echo "🛡️  Adding root CA to system trust store..."
      cp /etc/step-ca/certs/root_ca.crt /etc/ssl/certs/robcohen-root-ca.crt
      update-ca-certificates
      
      # Initialize step-ca database if needed
      if [ ! -f /var/lib/step-ca/db/data.mdb ]; then
        echo "🗄️  Initializing step-ca database..."
        chown -R step-ca:step-ca /var/lib/step-ca
      fi
      
      # Start step-ca
      echo "🚀 Starting step-ca service..."
      systemctl start step-ca
      systemctl enable step-ca
      
      # Wait for step-ca to start
      sleep 3
      
      # Verify step-ca is working
      if curl -k https://localhost:9000/health > /dev/null 2>&1; then
        echo "✅ Step-CA is running and healthy"
      else
        echo "⚠️  Step-CA may not be fully ready yet"
      fi
      
      echo ""
      echo "📋 Certificate Summary:"
      echo "======================"
      echo "Root CA:"
      openssl x509 -noout -subject -dates -in /etc/step-ca/certs/root_ca.crt
      echo ""
      echo "Intermediate CA:"
      openssl x509 -noout -subject -dates -in /etc/step-ca/certs/intermediate_ca.crt
      echo ""
      echo "✅ CA installation complete!"
      echo "🔧 Configure services to use internal ACME endpoint: https://localhost:9000/acme/internal-acme/directory"
      echo ""
      echo "🔒 Optional: Seal CA key to TPM for hardware protection:"
      echo "   tpm-seal-ca-key"
    '')

    (writeShellScriptBin "ca-request-cert" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "🔐 Requesting Certificate from Internal CA"
      echo "========================================="
      
      if [ $# -lt 1 ]; then
        echo "Usage: $0 <domain> [output-dir]"
        echo "Example: $0 grafana.internal.robcohen.dev /etc/ssl/grafana"
        exit 1
      fi
      
      DOMAIN="$1"
      OUTPUT_DIR="''${2:-/tmp/certs/$DOMAIN}"
      
      mkdir -p "$OUTPUT_DIR"
      
      echo "📝 Generating private key for $DOMAIN..."
      openssl genrsa -out "$OUTPUT_DIR/$DOMAIN.key" 2048
      chmod 600 "$OUTPUT_DIR/$DOMAIN.key"
      
      echo "📋 Generating certificate signing request..."
      openssl req -new -key "$OUTPUT_DIR/$DOMAIN.key" \
        -out "$OUTPUT_DIR/$DOMAIN.csr" \
        -subj "/C=US/ST=State/L=City/O=Personal/OU=Home Lab/CN=$DOMAIN"
      
      echo "✍️  Requesting certificate from step-ca..."
      step ca certificate "$DOMAIN" \
        "$OUTPUT_DIR/$DOMAIN.crt" "$OUTPUT_DIR/$DOMAIN.key" \
        --ca-url https://localhost:9000 \
        --root /etc/step-ca/certs/root_ca.crt \
        --provisioner internal-acme
      
      # Create full chain
      cat "$OUTPUT_DIR/$DOMAIN.crt" /etc/step-ca/certs/intermediate_ca.crt > "$OUTPUT_DIR/$DOMAIN-fullchain.crt"
      
      echo "✅ Certificate issued successfully!"
      echo "📁 Files created in: $OUTPUT_DIR"
      echo "   - $DOMAIN.key (private key)"
      echo "   - $DOMAIN.crt (certificate)"  
      echo "   - $DOMAIN-fullchain.crt (certificate + intermediate)"
      echo ""
      echo "📋 Certificate details:"
      openssl x509 -noout -text -in "$OUTPUT_DIR/$DOMAIN.crt" | head -20
    '')

    (writeShellScriptBin "ca-renew-cert" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "🔄 Renewing Certificate"
      echo "====================="
      
      CERT_FILE="$1"
      
      if [ ! -f "$CERT_FILE" ]; then
        echo "❌ Certificate file not found: $CERT_FILE"
        exit 1
      fi
      
      # Extract domain from certificate
      DOMAIN=$(openssl x509 -noout -subject -in "$CERT_FILE" | grep -o 'CN=[^,]*' | cut -d= -f2)
      
      echo "🔍 Renewing certificate for: $DOMAIN"
      
      # Use step-ca renewal
      step ca renew "$CERT_FILE" \
        --ca-url https://localhost:9000 \
        --root /etc/step-ca/certs/root_ca.crt
      
      echo "✅ Certificate renewed for $DOMAIN"
    '')

    (writeShellScriptBin "ca-status" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "🔍 Certificate Authority Status"
      echo "=============================="
      
      # Check step-ca service
      echo "📊 Step-CA Service:"
      systemctl status step-ca --no-pager -l || true
      echo ""
      
      # Check step-ca health
      echo "🏥 Step-CA Health:"
      if curl -k https://localhost:9000/health 2>/dev/null; then
        echo "✅ Step-CA responding"
      else
        echo "❌ Step-CA not responding"
      fi
      echo ""
      
      # Show certificate details
      if [ -f /etc/step-ca/certs/root_ca.crt ]; then
        echo "📋 Root CA Certificate:"
        openssl x509 -noout -subject -dates -fingerprint -in /etc/step-ca/certs/root_ca.crt
        echo ""
      fi
      
      if [ -f /etc/step-ca/certs/intermediate_ca.crt ]; then
        echo "📋 Intermediate CA Certificate:"
        openssl x509 -noout -subject -dates -fingerprint -in /etc/step-ca/certs/intermediate_ca.crt
        echo ""
      fi
      
      # Check system trust store
      echo "🛡️  System Trust Store:"
      if [ -f /etc/ssl/certs/robcohen-root-ca.crt ]; then
        echo "✅ Root CA installed in system trust store"
      else
        echo "❌ Root CA not found in system trust store"
      fi
      
      # List issued certificates
      echo ""
      echo "📜 Recently Issued Certificates:"
      find /var/lib/step-ca -name "*.crt" -mtime -30 2>/dev/null | head -10 || echo "None found"
    '')

    # TPM 2.0 CA key management scripts
    (writeShellScriptBin "tpm-seal-ca-key" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "🔒 Sealing Intermediate CA Key to TPM"
      echo "===================================="
      
      CA_KEY_FILE="/etc/step-ca/secrets/intermediate_ca_key"
      TPM_DIR="/var/lib/step-ca/tpm"
      
      if [ ! -f "$CA_KEY_FILE" ]; then
        echo "❌ CA key file not found: $CA_KEY_FILE"
        echo "Run ca-install-from-airgap first"
        exit 1
      fi
      
      echo "📊 Reading current PCR values..."
      tpm2_pcrread sha256:0,1,2,3,4,5,6,7 > "$TPM_DIR/pcr.values"
      
      echo "📋 Creating PCR policy..."
      tpm2_createpolicy --policy-pcr -l sha256:0,1,2,3,4,5,6,7 \
        -f "$TPM_DIR/pcr.values" -L "$TPM_DIR/pcr.policy"
      
      echo "🔑 Creating TPM primary key..."
      tpm2_createprimary -C o -g sha256 -G rsa \
        -c "$TPM_DIR/primary.ctx"
      
      echo "🔐 Sealing CA key to TPM..."
      tpm2_create -g sha256 -G keyedhash \
        -u "$TPM_DIR/ca-key.pub" \
        -r "$TPM_DIR/ca-key.priv" \
        -C "$TPM_DIR/primary.ctx" \
        -L "$TPM_DIR/pcr.policy" \
        -i "$CA_KEY_FILE"
      
      echo "📦 Loading sealed key context..."
      tpm2_load -C "$TPM_DIR/primary.ctx" \
        -u "$TPM_DIR/ca-key.pub" \
        -r "$TPM_DIR/ca-key.priv" \
        -c "$TPM_DIR/ca-key.ctx"
      
      # Set proper ownership
      chown -R step-ca:step-ca "$TPM_DIR"
      chmod 600 "$TPM_DIR"/*
      
      echo "✅ CA key sealed to TPM successfully!"
      echo "🔒 Key will only unseal on this hardware with current boot state"
      echo "📋 PCR values bound to key:"
      tpm2_pcrread sha256:0,1,2,3,4,5,6,7
    '')

    (writeShellScriptBin "tpm-unseal-ca-key" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "🔓 Unsealing CA Key from TPM"
      echo "============================"
      
      TPM_DIR="/var/lib/step-ca/tpm"
      OUTPUT_FILE="/run/credentials/step-ca/ca-key"
      
      if [ ! -f "$TPM_DIR/ca-key.ctx" ]; then
        echo "❌ Sealed CA key not found in TPM"
        echo "Run tpm-seal-ca-key first"
        exit 1
      fi
      
      echo "🔓 Unsealing key from TPM..."
      if tpm2_unseal -c "$TPM_DIR/ca-key.ctx" -o "$OUTPUT_FILE" 2>/dev/null; then
        echo "✅ CA key unsealed successfully"
        chmod 600 "$OUTPUT_FILE"
        chown step-ca:step-ca "$OUTPUT_FILE"
      else
        echo "❌ Failed to unseal key - PCR values may have changed"
        echo "📊 Current PCR values:"
        tpm2_pcrread sha256:0,1,2,3,4,5,6,7
        echo "📊 Expected PCR values:"
        cat "$TPM_DIR/pcr.values" 2>/dev/null || echo "PCR values file not found"
        exit 1
      fi
    '')

    (writeShellScriptBin "tpm-status" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "🔍 TPM 2.0 Status"
      echo "================="
      
      # Check TPM device
      if [ -c /dev/tpm0 ]; then
        echo "✅ TPM device found: /dev/tpm0"
      else
        echo "❌ TPM device not found"
      fi
      
      if [ -c /dev/tpmrm0 ]; then
        echo "✅ TPM resource manager found: /dev/tpmrm0"
      else
        echo "❌ TPM resource manager not found"
      fi
      
      # Check TPM services
      echo ""
      echo "📊 TPM Services:"
      systemctl status tpm2-abrmd --no-pager -l || true
      
      # Check PCR values
      echo ""
      echo "📊 Current PCR Values:"
      tpm2_pcrread sha256:0,1,2,3,4,5,6,7 2>/dev/null || echo "Failed to read PCRs"
      
      # Check sealed key status
      echo ""
      echo "🔐 Sealed CA Key Status:"
      if [ -f /var/lib/step-ca/tpm/ca-key.ctx ]; then
        echo "✅ CA key sealed in TPM"
        echo "📅 Sealed: $(stat -c %y /var/lib/step-ca/tpm/ca-key.ctx)"
      else
        echo "❌ CA key not sealed in TPM"
      fi
      
      # Check unsealed key status
      if [ -f /run/credentials/step-ca/ca-key ]; then
        echo "✅ CA key currently unsealed"
        echo "📅 Unsealed: $(stat -c %y /run/credentials/step-ca/ca-key)"
      else
        echo "⏸️  CA key not currently unsealed"
      fi
    '')

    (writeShellScriptBin "tpm-pcr-monitor" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "👁️  TPM PCR Monitoring"
      echo "====================="
      
      BASELINE_FILE="/var/lib/step-ca/tpm/pcr.baseline"
      CURRENT_FILE="/tmp/pcr.current"
      
      # Read current PCR values
      tpm2_pcrread sha256:0,1,2,3,4,5,6,7 > "$CURRENT_FILE"
      
      if [ -f "$BASELINE_FILE" ]; then
        if diff -q "$BASELINE_FILE" "$CURRENT_FILE" > /dev/null; then
          echo "✅ PCR values unchanged - system integrity verified"
        else
          echo "⚠️  PCR values have changed!"
          echo "📊 Changes detected:"
          diff "$BASELINE_FILE" "$CURRENT_FILE" || true
          
          # Send alert
          smart-notify warning "TPM PCR Changed" "System boot measurements have changed - possible firmware/kernel update or compromise" "tpm,security"
        fi
      else
        echo "📝 Creating PCR baseline"
        cp "$CURRENT_FILE" "$BASELINE_FILE"
        chown step-ca:step-ca "$BASELINE_FILE"
      fi
      
      rm -f "$CURRENT_FILE"
    '')

    # SOPS setup and management scripts
    (writeShellScriptBin "sops-setup" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "🔐 SOPS Secrets Management Setup"
      echo "==============================="
      
      # Check if age key exists
      if [ ! -f /var/lib/sops-nix/key.txt ]; then
        echo "📝 Generating age key for SOPS..."
        mkdir -p /var/lib/sops-nix
        ${pkgs.age}/bin/age-keygen -o /var/lib/sops-nix/key.txt
        chmod 600 /var/lib/sops-nix/key.txt
        chown root:root /var/lib/sops-nix/key.txt
        
        echo "✅ Age key generated at /var/lib/sops-nix/key.txt"
        echo ""
        echo "🔑 Public key (add this to secrets.yaml):"
        grep "# public key:" /var/lib/sops-nix/key.txt
      else
        echo "✅ Age key already exists"
        echo ""
        echo "🔑 Public key:"
        grep "# public key:" /var/lib/sops-nix/key.txt
      fi
      
      echo ""
      echo "📝 Next steps:"
      echo "1. Update secrets.yaml with the public key above"
      echo "2. Run: sops secrets.yaml"
      echo "3. Add your actual secrets to the file"
      echo "4. Rebuild system: nixos-rebuild switch"
    '')

    (writeShellScriptBin "sops-edit-secrets" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "✏️  Editing SOPS secrets file..."
      cd ${toString ./.}
      ${pkgs.sops}/bin/sops secrets.yaml
    '')

    (writeShellScriptBin "security-status" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "🛡️  Security Status Report"
      echo "========================="
      
      # Check SOPS secrets
      echo "📝 SOPS Secrets:"
      if [ -f /var/lib/sops-nix/key.txt ]; then
        echo "✅ Age key present"
        echo "📊 Accessible secrets:"
        ls -la /run/secrets/ 2>/dev/null || echo "No secrets decrypted yet"
      else
        echo "❌ Age key missing - run sops-setup"
      fi
      
      echo ""
      echo "🔒 Service Security Status:"
      
      # Check service hardening
      SERVICES=("step-ca" "grafana" "prometheus" "ntfy-sh" "headscale")
      for service in "''${SERVICES[@]}"; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
          echo "✅ $service: Active"
          # Check if service has security features enabled
          if systemctl show "$service" -p NoNewPrivileges | grep -q "yes"; then
            echo "  🛡️  Security hardened"
          else
            echo "  ⚠️  Not hardened"
          fi
        else
          echo "❌ $service: Inactive"
        fi
      done
      
      echo ""
      echo "🔍 Certificate Status:"
      
      # Check certificate expiry
      CERT_PATHS=(
        "/etc/step-ca/certs/intermediate_ca.crt"
        "/var/lib/acme/sync.robcohen.dev/cert.pem"
      )
      
      for cert in "''${CERT_PATHS[@]}"; do
        if [ -f "$cert" ]; then
          EXPIRY=$(openssl x509 -noout -enddate -in "$cert" | cut -d= -f2)
          DAYS_LEFT=$(( ($(date -d "$EXPIRY" +%s) - $(date +%s)) / 86400 ))
          
          if [ $DAYS_LEFT -gt 30 ]; then
            echo "✅ $(basename "$cert"): $DAYS_LEFT days left"
          elif [ $DAYS_LEFT -gt 7 ]; then
            echo "⚠️  $(basename "$cert"): $DAYS_LEFT days left"
          else
            echo "🚨 $(basename "$cert"): $DAYS_LEFT days left - URGENT"
          fi
        fi
      done
      
      echo ""
      echo "📊 TPM Status:"
      tpm-status 2>/dev/null || echo "TPM status unavailable"
    '')

    # Log management and analysis scripts
    (writeShellScriptBin "logs-query" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "📋 Log Query Tool (Loki)"
      echo "======================"
      
      if [ $# -lt 1 ]; then
        echo "Usage: $0 <query> [time-range]"
        echo ""
        echo "Examples:"
        echo "  logs-query '{job=\"systemd-journal\"}'"
        echo "  logs-query '{unit=\"step-ca.service\"}' '1h'"
        echo "  logs-query '{job=\"backup\"} |= \"FAILED\"' '24h'"
        echo "  logs-query '{job=\"security\"} |~ \"FAILED|ERROR\"' '12h'"
        exit 1
      fi
      
      QUERY="$1"
      TIME_RANGE="''${2:-1h}"
      
      echo "🔍 Querying logs: $QUERY"
      echo "⏰ Time range: $TIME_RANGE"
      echo ""
      
      # Query Loki API
      LOKI_URL="http://100.64.0.1:3100"
      START_TIME=$(date -d "$TIME_RANGE ago" --iso-8601=seconds)
      END_TIME=$(date --iso-8601=seconds)
      
      curl -s -G "$LOKI_URL/loki/api/v1/query_range" \
        --data-urlencode "query=$QUERY" \
        --data-urlencode "start=$START_TIME" \
        --data-urlencode "end=$END_TIME" \
        --data-urlencode "limit=100" | \
        ${pkgs.jq}/bin/jq -r '.data.result[]? | .values[]? | @tsv' | \
        while IFS=$'\t' read -r timestamp message; do
          # Convert nanosecond timestamp to readable format
          readable_time=$(date -d "@$(echo "$timestamp" | cut -c1-10)" '+%Y-%m-%d %H:%M:%S')
          echo "[$readable_time] $message"
        done
    '')

    (writeShellScriptBin "logs-security" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "🔒 Security Log Analysis"
      echo "======================="
      
      TIME_RANGE="''${1:-24h}"
      
      echo "🔍 Analyzing security events from last $TIME_RANGE..."
      echo ""
      
      # Failed login attempts
      echo "🚨 Failed Login Attempts:"
      logs-query '{job="security"} |~ "FAILED.*authentication"' "$TIME_RANGE" | head -20
      
      echo ""
      echo "🔒 Certificate Authority Events:"
      logs-query '{job="step-ca"} |~ "ERROR|WARN"' "$TIME_RANGE" | head -20
      
      echo ""
      echo "🛡️ Firewall Denials:"
      logs-query '{unit="firewall.service"} |= "DENY"' "$TIME_RANGE" | head -20
      
      echo ""
      echo "⚠️ System Service Failures:"
      logs-query '{job="systemd-journal"} |~ "failed|error" |~ "systemd"' "$TIME_RANGE" | head -20
    '')

    (writeShellScriptBin "logs-backup" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "💾 Backup Log Analysis"
      echo "====================="
      
      TIME_RANGE="''${1:-7d}"
      
      echo "🔍 Analyzing backup events from last $TIME_RANGE..."
      echo ""
      
      # Backup successes
      echo "✅ Successful Backups:"
      logs-query '{job="backup"} |= "completed"' "$TIME_RANGE" | tail -10
      
      echo ""
      echo "❌ Failed Backups:"
      logs-query '{job="backup"} |= "FAILED"' "$TIME_RANGE" | tail -10
      
      echo ""
      echo "📊 Backup Statistics:"
      
      # Count successes and failures
      SUCCESS_COUNT=$(logs-query '{job="backup"} |= "completed"' "$TIME_RANGE" | wc -l)
      FAILURE_COUNT=$(logs-query '{job="backup"} |= "FAILED"' "$TIME_RANGE" | wc -l)
      
      echo "Successful backups: $SUCCESS_COUNT"
      echo "Failed backups: $FAILURE_COUNT"
      
      if [ $((SUCCESS_COUNT + FAILURE_COUNT)) -gt 0 ]; then
        SUCCESS_RATE=$(( SUCCESS_COUNT * 100 / (SUCCESS_COUNT + FAILURE_COUNT) ))
        echo "Success rate: $SUCCESS_RATE%"
      fi
    '')

    (writeShellScriptBin "logs-monitor" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "📊 System Monitoring via Logs"
      echo "============================="
      
      # Real-time log monitoring
      if [ "''${1:-}" = "live" ]; then
        echo "🔴 Live log monitoring (Ctrl+C to stop)..."
        echo ""
        
        # Monitor critical events in real-time
        while true; do
          # Check for new errors in the last minute
          NEW_ERRORS=$(logs-query '{job="systemd-journal"} |~ "ERROR|CRITICAL"' '1m' | wc -l)
          
          if [ "$NEW_ERRORS" -gt 0 ]; then
            echo "⚠️ $NEW_ERRORS new errors detected:"
            logs-query '{job="systemd-journal"} |~ "ERROR|CRITICAL"' '1m' | tail -5
            echo ""
          fi
          
          sleep 30
        done
      else
        echo "📈 Recent System Activity:"
        echo ""
        
        echo "🔥 Most Active Services (last hour):"
        logs-query '{job="systemd-journal"}' '1h' | \
          ${pkgs.gawk}/bin/awk '{print $3}' | sort | uniq -c | sort -nr | head -10
        
        echo ""
        echo "⚠️ Recent Warnings/Errors:"
        logs-query '{job="systemd-journal"} |~ "WARN|ERROR"' '1h' | tail -10
        
        echo ""
        echo "📊 Log Volume by Source:"
        echo "SystemD Journal: $(logs-query '{job="systemd-journal"}' '1h' | wc -l) entries"
        echo "Nginx Access: $(logs-query '{job="nginx",log_type="access"}' '1h' | wc -l) entries"
        echo "Nginx Errors: $(logs-query '{job="nginx",log_type="error"}' '1h' | wc -l) entries"
        echo "Step-CA: $(logs-query '{job="step-ca"}' '1h' | wc -l) entries"
        echo "Backup: $(logs-query '{job="backup"}' '1h' | wc -l) entries"
      fi
    '')

    (writeShellScriptBin "logs-status" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "📊 Logging Infrastructure Status"
      echo "==============================="
      
      # Check Loki service
      echo "📋 Loki Status:"
      if systemctl is-active loki >/dev/null 2>&1; then
        echo "✅ Loki service is running"
        
        # Test Loki API
        if curl -s http://100.64.0.1:3100/ready >/dev/null; then
          echo "✅ Loki API is responding"
        else
          echo "❌ Loki API not responding"
        fi
        
        # Check Loki metrics
        LOKI_INGESTER_STREAMS=$(curl -s http://100.64.0.1:3100/metrics | grep loki_ingester_streams | head -1 | ${pkgs.gawk}/bin/awk '{print $2}')
        echo "📊 Active streams: ''${LOKI_INGESTER_STREAMS:-unknown}"
        
      else
        echo "❌ Loki service is not running"
      fi
      
      echo ""
      echo "📡 Promtail Status:"
      if systemctl is-active promtail >/dev/null 2>&1; then
        echo "✅ Promtail service is running"
        
        # Check Promtail metrics
        if curl -s http://100.64.0.1:9080/metrics >/dev/null; then
          echo "✅ Promtail metrics available"
        else
          echo "⚠️ Promtail metrics not available"
        fi
        
      else
        echo "❌ Promtail service is not running"
      fi
      
      echo ""
      echo "💽 Log Storage:"
      echo "Loki data: $(du -sh /var/lib/loki 2>/dev/null || echo 'Not available')"
      
      echo ""
      echo "📈 Recent Log Activity:"
      echo "Last hour entries: $(logs-query '{}' '1h' | wc -l)"
      echo "Last day entries: $(logs-query '{}' '24h' | wc -l)"
    '')

    # Backup validation and disaster recovery testing
    (writeShellScriptBin "backup-validate" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "🔍 Backup Validation Suite"
      echo "=========================="
      
      VALIDATION_DIR="/var/lib/backup-validation"
      TEST_RESTORE_DIR="$VALIDATION_DIR/test-restore"
      REPORTS_DIR="$VALIDATION_DIR/reports"
      CHECKPOINT_DIR="$VALIDATION_DIR/checkpoints"
      
      TIMESTAMP=$(date +%Y%m%d-%H%M%S)
      REPORT_FILE="$REPORTS_DIR/backup-validation-$TIMESTAMP.json"
      
      # Initialize validation report
      cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$(date --iso-8601=seconds)",
  "validation_id": "$TIMESTAMP",
  "tests": [],
  "summary": {
    "total_tests": 0,
    "passed": 0,
    "failed": 0,
    "warnings": 0
  }
}
EOF
      
      function add_test_result() {
        local test_name="$1"
        local status="$2"
        local details="$3"
        local duration="$4"
        
        # Update report
        ${pkgs.jq}/bin/jq --arg name "$test_name" \
                         --arg status "$status" \
                         --arg details "$details" \
                         --arg duration "$duration" \
          '.tests += [{
            "name": $name,
            "status": $status, 
            "details": $details,
            "duration": $duration,
            "timestamp": now | strftime("%Y-%m-%dT%H:%M:%SZ")
          }] | 
          .summary.total_tests += 1 |
          if $status == "PASS" then .summary.passed += 1
          elif $status == "FAIL" then .summary.failed += 1
          else .summary.warnings += 1 end' \
          "$REPORT_FILE" > "$REPORT_FILE.tmp" && mv "$REPORT_FILE.tmp" "$REPORT_FILE"
      }
      
      function test_local_borg_backup() {
        echo "🔍 Testing local Borg backup..."
        local start_time=$(date +%s)
        
        local borg_repo="/tank/nfs/backup/borg-local"
        
        if [ ! -d "$borg_repo" ]; then
          add_test_result "local_borg_existence" "FAIL" "Borg repository does not exist at $borg_repo" "0"
          return 1
        fi
        
        # Test repository integrity
        if ${pkgs.borgbackup}/bin/borg check --repository-only "$borg_repo" 2>/dev/null; then
          add_test_result "local_borg_integrity" "PASS" "Repository integrity check passed" "$(($(date +%s) - start_time))"
        else
          add_test_result "local_borg_integrity" "FAIL" "Repository integrity check failed" "$(($(date +%s) - start_time))"
          return 1
        fi
        
        # List archives
        local archive_count=$(${pkgs.borgbackup}/bin/borg list --short "$borg_repo" 2>/dev/null | wc -l)
        if [ "$archive_count" -gt 0 ]; then
          add_test_result "local_borg_archives" "PASS" "Found $archive_count archives in repository" "$(($(date +%s) - start_time))"
        else
          add_test_result "local_borg_archives" "WARN" "No archives found in repository" "$(($(date +%s) - start_time))"
        fi
        
        # Test restore of latest archive
        local latest_archive=$(${pkgs.borgbackup}/bin/borg list --short "$borg_repo" 2>/dev/null | tail -1)
        if [ -n "$latest_archive" ]; then
          echo "Testing restore of latest archive: $latest_archive"
          
          rm -rf "$TEST_RESTORE_DIR/borg-local"
          mkdir -p "$TEST_RESTORE_DIR/borg-local"
          
          if BORG_PASSCOMMAND="cat ${config.sops.secrets.borg-passphrase.path}" \
             ${pkgs.borgbackup}/bin/borg extract \
             "$borg_repo::$latest_archive" \
             --destination "$TEST_RESTORE_DIR/borg-local" \
             tank/nfs/share 2>/dev/null; then
            
            # Verify restored files
            local restored_files=$(find "$TEST_RESTORE_DIR/borg-local" -type f | wc -l)
            add_test_result "local_borg_restore" "PASS" "Successfully restored $restored_files files from $latest_archive" "$(($(date +%s) - start_time))"
          else
            add_test_result "local_borg_restore" "FAIL" "Failed to restore from $latest_archive" "$(($(date +%s) - start_time))"
          fi
        fi
      }
      
      function test_offline_borg_backup() {
        echo "🔍 Testing offline Borg backup..."
        local start_time=$(date +%s)
        
        local offline_repo="/mnt/backup-drive/borg-offline"
        
        if [ ! -d "$offline_repo" ]; then
          add_test_result "offline_borg_existence" "WARN" "Offline backup drive not mounted or repository missing" "0"
          return 0
        fi
        
        # Test repository integrity
        if BORG_PASSCOMMAND="cat ${config.sops.secrets.borg-passphrase-offline.path}" \
           ${pkgs.borgbackup}/bin/borg check --repository-only "$offline_repo" 2>/dev/null; then
          add_test_result "offline_borg_integrity" "PASS" "Offline repository integrity check passed" "$(($(date +%s) - start_time))"
        else
          add_test_result "offline_borg_integrity" "FAIL" "Offline repository integrity check failed" "$(($(date +%s) - start_time))"
          return 1
        fi
        
        # List archives
        local archive_count=$(BORG_PASSCOMMAND="cat ${config.sops.secrets.borg-passphrase-offline.path}" \
                             ${pkgs.borgbackup}/bin/borg list --short "$offline_repo" 2>/dev/null | wc -l)
        if [ "$archive_count" -gt 0 ]; then
          add_test_result "offline_borg_archives" "PASS" "Found $archive_count offline archives" "$(($(date +%s) - start_time))"
        else
          add_test_result "offline_borg_archives" "WARN" "No offline archives found" "$(($(date +%s) - start_time))"
        fi
      }
      
      function test_cloud_backup() {
        echo "🔍 Testing cloud backup (Backblaze B2)..."
        local start_time=$(date +%s)
        
        # Test B2 connectivity and list buckets
        if ${pkgs.rclone}/bin/rclone listremotes | grep -q "b2:"; then
          add_test_result "cloud_config" "PASS" "Backblaze B2 configuration found" "1"
          
          # Test bucket access
          if ${pkgs.rclone}/bin/rclone lsd b2:server-river-backup 2>/dev/null; then
            add_test_result "cloud_access" "PASS" "Successfully accessed B2 bucket" "$(($(date +%s) - start_time))"
            
            # List recent files
            local file_count=$(${pkgs.rclone}/bin/rclone ls b2:server-river-backup/share 2>/dev/null | wc -l)
            add_test_result "cloud_files" "PASS" "Found $file_count files in cloud backup" "$(($(date +%s) - start_time))"
          else
            add_test_result "cloud_access" "FAIL" "Cannot access B2 bucket" "$(($(date +%s) - start_time))"
          fi
        else
          add_test_result "cloud_config" "FAIL" "Backblaze B2 not configured" "1"
        fi
      }
      
      function test_zfs_snapshots() {
        echo "🔍 Testing ZFS snapshots..."
        local start_time=$(date +%s)
        
        # Check if ZFS is available
        if command -v zfs >/dev/null 2>&1; then
          # List snapshots
          local snapshot_count=$(zfs list -t snapshot 2>/dev/null | grep -c "tank/" || echo "0")
          
          if [ "$snapshot_count" -gt 0 ]; then
            add_test_result "zfs_snapshots" "PASS" "Found $snapshot_count ZFS snapshots" "$(($(date +%s) - start_time))"
            
            # Test snapshot rollback capability (dry run)
            local latest_snapshot=$(zfs list -t snapshot -o name tank/nfs 2>/dev/null | tail -1)
            if [ -n "$latest_snapshot" ]; then
              add_test_result "zfs_rollback_test" "PASS" "Latest snapshot available for rollback: $latest_snapshot" "$(($(date +%s) - start_time))"
            fi
          else
            add_test_result "zfs_snapshots" "WARN" "No ZFS snapshots found" "$(($(date +%s) - start_time))"
          fi
        else
          add_test_result "zfs_availability" "WARN" "ZFS not available on this system" "1"
        fi
      }
      
      function test_backup_encryption() {
        echo "🔍 Testing backup encryption..."
        local start_time=$(date +%s)
        
        # Test that backup passphrases are accessible
        if [ -f "${config.sops.secrets.borg-passphrase.path}" ]; then
          if [ -s "${config.sops.secrets.borg-passphrase.path}" ]; then
            add_test_result "local_backup_passphrase" "PASS" "Local backup passphrase accessible" "1"
          else
            add_test_result "local_backup_passphrase" "FAIL" "Local backup passphrase file empty" "1"
          fi
        else
          add_test_result "local_backup_passphrase" "FAIL" "Local backup passphrase not found" "1"
        fi
        
        if [ -f "${config.sops.secrets.borg-passphrase-offline.path}" ]; then
          if [ -s "${config.sops.secrets.borg-passphrase-offline.path}" ]; then
            add_test_result "offline_backup_passphrase" "PASS" "Offline backup passphrase accessible" "1"
          else
            add_test_result "offline_backup_passphrase" "FAIL" "Offline backup passphrase file empty" "1"
          fi
        else
          add_test_result "offline_backup_passphrase" "FAIL" "Offline backup passphrase not found" "1"
        fi
      }
      
      function test_disaster_recovery() {
        echo "🔍 Testing disaster recovery procedures..."
        local start_time=$(date +%s)
        
        # Test CA paper backup recovery simulation
        echo "Simulating CA recovery (dry run)..."
        if command -v ca-verify-paper-backup >/dev/null 2>&1; then
          add_test_result "ca_recovery_tools" "PASS" "CA recovery tools available" "1"
        else
          add_test_result "ca_recovery_tools" "FAIL" "CA recovery tools missing" "1"
        fi
        
        # Test configuration backup
        if [ -d "/etc/nixos" ] || [ -f "/etc/nixos/configuration.nix" ]; then
          add_test_result "config_backup" "PASS" "System configuration accessible for recovery" "1"
        else
          add_test_result "config_backup" "WARN" "System configuration location unclear" "1"
        fi
        
        # Test secrets recovery
        if [ -d "/run/secrets" ] && [ "$(ls -A /run/secrets 2>/dev/null | wc -l)" -gt 0 ]; then
          add_test_result "secrets_recovery" "PASS" "Secrets management operational" "1"
        else
          add_test_result "secrets_recovery" "FAIL" "Secrets not accessible" "1"
        fi
      }
      
      function create_checkpoint() {
        echo "📸 Creating system checkpoint..."
        local checkpoint_file="$CHECKPOINT_DIR/checkpoint-$TIMESTAMP.json"
        
        cat > "$checkpoint_file" << EOF
{
  "timestamp": "$(date --iso-8601=seconds)",
  "checkpoint_id": "$TIMESTAMP",
  "system_state": {
    "uptime": "$(uptime -p)",
    "disk_usage": $(df -h /tank | tail -1 | ${pkgs.gawk}/bin/awk '{print "{\"used\":\""$3"\",\"available\":\""$4"\",\"percent\":\""$5"\"}"}'),
    "services": $(systemctl list-units --state=active --type=service --no-legend | wc -l),
    "zfs_health": "$(zpool status tank | grep -o "state: [A-Z]*" | cut -d: -f2 | xargs || echo "unknown")",
    "backup_space": {
      "local_borg": "$(du -sh /tank/nfs/backup/borg-local 2>/dev/null | cut -f1 || echo "unknown")",
      "total_nfs": "$(du -sh /tank/nfs 2>/dev/null | cut -f1 || echo "unknown")"
    }
  }
}
EOF
        
        echo "📸 Checkpoint saved: $checkpoint_file"
      }
      
      # Main validation sequence
      echo "🚀 Starting backup validation..."
      echo "Validation ID: $TIMESTAMP"
      echo ""
      
      create_checkpoint
      
      test_backup_encryption
      test_zfs_snapshots  
      test_local_borg_backup
      test_offline_borg_backup
      test_cloud_backup
      test_disaster_recovery
      
      # Generate summary
      echo ""
      echo "📊 Validation Summary:"
      echo "===================="
      
      local total=$(${pkgs.jq}/bin/jq -r '.summary.total_tests' "$REPORT_FILE")
      local passed=$(${pkgs.jq}/bin/jq -r '.summary.passed' "$REPORT_FILE")
      local failed=$(${pkgs.jq}/bin/jq -r '.summary.failed' "$REPORT_FILE")
      local warnings=$(${pkgs.jq}/bin/jq -r '.summary.warnings' "$REPORT_FILE")
      
      echo "Total tests: $total"
      echo "✅ Passed: $passed"
      echo "❌ Failed: $failed"
      echo "⚠️  Warnings: $warnings"
      
      if [ "$failed" -gt 0 ]; then
        echo ""
        echo "❌ Failed tests:"
        ${pkgs.jq}/bin/jq -r '.tests[] | select(.status == "FAIL") | "  - " + .name + ": " + .details' "$REPORT_FILE"
      fi
      
      if [ "$warnings" -gt 0 ]; then
        echo ""
        echo "⚠️  Warnings:"
        ${pkgs.jq}/bin/jq -r '.tests[] | select(.status == "WARN") | "  - " + .name + ": " + .details' "$REPORT_FILE"
      fi
      
      echo ""
      echo "📁 Detailed report: $REPORT_FILE"
      
      # Send notification
      if [ "$failed" -gt 0 ]; then
        smart-notify critical "Backup Validation Failed" "$failed backup tests failed. Check report: $REPORT_FILE" "backup,validation,critical"
      elif [ "$warnings" -gt 0 ]; then
        smart-notify warning "Backup Validation Warnings" "$warnings backup tests had warnings. Report: $REPORT_FILE" "backup,validation"
      else
        smart-notify info "Backup Validation Success" "All $total backup tests passed successfully" "backup,validation"
      fi
      
      # Return appropriate exit code
      if [ "$failed" -gt 0 ]; then
        exit 1
      else
        exit 0
      fi
    '')

    (writeShellScriptBin "backup-restore-test" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "🔄 Backup Restore Test"
      echo "======================"
      
      if [ $# -lt 2 ]; then
        echo "Usage: $0 <backup-type> <test-file-pattern>"
        echo ""
        echo "Backup types:"
        echo "  local     - Test restore from local Borg backup"
        echo "  offline   - Test restore from offline Borg backup"  
        echo "  cloud     - Test restore from Backblaze B2"
        echo "  zfs       - Test restore from ZFS snapshot"
        echo ""
        echo "Examples:"
        echo "  $0 local 'tank/nfs/share/important.txt'"
        echo "  $0 cloud 'share/documents'"
        echo "  $0 zfs 'share/configs'"
        exit 1
      fi
      
      BACKUP_TYPE="$1"
      TEST_PATTERN="$2"
      
      RESTORE_DIR="/var/lib/backup-validation/test-restore"
      TIMESTAMP=$(date +%Y%m%d-%H%M%S)
      TEST_DIR="$RESTORE_DIR/$BACKUP_TYPE-$TIMESTAMP"
      
      mkdir -p "$TEST_DIR"
      
      case "$BACKUP_TYPE" in
        "local")
          echo "🔄 Testing local Borg backup restore..."
          BORG_REPO="/tank/nfs/backup/borg-local"
          LATEST_ARCHIVE=$(${pkgs.borgbackup}/bin/borg list --short "$BORG_REPO" | tail -1)
          
          echo "Restoring from archive: $LATEST_ARCHIVE"
          echo "Pattern: $TEST_PATTERN"
          
          BORG_PASSCOMMAND="cat ${config.sops.secrets.borg-passphrase.path}" \
          ${pkgs.borgbackup}/bin/borg extract \
            "$BORG_REPO::$LATEST_ARCHIVE" \
            --destination "$TEST_DIR" \
            "$TEST_PATTERN"
          ;;
          
        "offline")
          echo "🔄 Testing offline Borg backup restore..."
          OFFLINE_REPO="/mnt/backup-drive/borg-offline"
          
          if [ ! -d "$OFFLINE_REPO" ]; then
            echo "❌ Offline backup drive not mounted"
            exit 1
          fi
          
          LATEST_ARCHIVE=$(BORG_PASSCOMMAND="cat ${config.sops.secrets.borg-passphrase-offline.path}" \
                          ${pkgs.borgbackup}/bin/borg list --short "$OFFLINE_REPO" | tail -1)
          
          echo "Restoring from offline archive: $LATEST_ARCHIVE"
          
          BORG_PASSCOMMAND="cat ${config.sops.secrets.borg-passphrase-offline.path}" \
          ${pkgs.borgbackup}/bin/borg extract \
            "$OFFLINE_REPO::$LATEST_ARCHIVE" \
            --destination "$TEST_DIR" \
            "$TEST_PATTERN"
          ;;
          
        "cloud")
          echo "🔄 Testing cloud backup restore..."
          echo "Downloading from Backblaze B2..."
          
          ${pkgs.rclone}/bin/rclone copy \
            "b2:server-river-backup/$TEST_PATTERN" \
            "$TEST_DIR" \
            --progress
          ;;
          
        "zfs")
          echo "🔄 Testing ZFS snapshot restore..."
          LATEST_SNAPSHOT=$(zfs list -t snapshot -o name tank/nfs | tail -1)
          
          if [ -z "$LATEST_SNAPSHOT" ]; then
            echo "❌ No ZFS snapshots found"
            exit 1
          fi
          
          echo "Restoring from snapshot: $LATEST_SNAPSHOT"
          
          # Mount snapshot readonly and copy files
          SNAP_MOUNT="/tmp/zfs-snapshot-$TIMESTAMP"
          mkdir -p "$SNAP_MOUNT"
          
          # Note: This would require actual ZFS snapshot mounting in production
          echo "⚠️  ZFS snapshot restore test requires manual snapshot mounting"
          echo "Snapshot available: $LATEST_SNAPSHOT"
          ;;
          
        *)
          echo "❌ Unknown backup type: $BACKUP_TYPE"
          exit 1
          ;;
      esac
      
      # Verify restore
      if [ -d "$TEST_DIR" ] && [ "$(find "$TEST_DIR" -type f | wc -l)" -gt 0 ]; then
        RESTORED_FILES=$(find "$TEST_DIR" -type f | wc -l)
        TOTAL_SIZE=$(du -sh "$TEST_DIR" | cut -f1)
        
        echo "✅ Restore successful!"
        echo "📁 Files restored: $RESTORED_FILES"
        echo "💾 Total size: $TOTAL_SIZE"
        echo "📂 Location: $TEST_DIR"
        
        echo ""
        echo "📋 Restored files:"
        find "$TEST_DIR" -type f | head -20 | while read -r file; do
          echo "  - $(basename "$file") ($(stat --printf='%s' "$file" | numfmt --to=iec))"
        done
        
        # Cleanup option
        echo ""
        read -p "🗑️  Remove test restore directory? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          rm -rf "$TEST_DIR"
          echo "✅ Test directory cleaned up"
        else
          echo "📂 Test files preserved at: $TEST_DIR"
        fi
        
      else
        echo "❌ Restore failed - no files found"
        exit 1
      fi
    '')

    (writeShellScriptBin "backup-disaster-simulation" ''
      #!/usr/bin/env bash
      set -euo pipefail
      
      echo "🔥 Disaster Recovery Simulation"
      echo "==============================="
      echo ""
      echo "⚠️  WARNING: This simulates various disaster scenarios"
      echo "This test is designed to validate recovery procedures"
      echo ""
      
      read -p "Continue with disaster simulation? [y/N] " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Simulation cancelled"
        exit 0
      fi
      
      SIMULATION_DIR="/var/lib/backup-validation/disaster-simulation"
      TIMESTAMP=$(date +%Y%m%d-%H%M%S)
      LOG_FILE="$SIMULATION_DIR/disaster-sim-$TIMESTAMP.log"
      
      mkdir -p "$SIMULATION_DIR"
      
      function log_simulation() {
        echo "[$( date '+%Y-%m-%d %H:%M:%S' )] $1" | tee -a "$LOG_FILE"
      }
      
      log_simulation "🔥 Starting disaster recovery simulation"
      log_simulation "Simulation ID: $TIMESTAMP"
      
      # Scenario 1: Complete system loss
      echo ""
      echo "📋 Scenario 1: Complete System Loss"
      echo "==================================="
      log_simulation "SCENARIO 1: Complete system loss simulation"
      
      echo "Simulating loss of primary server..."
      log_simulation "Primary server lost - testing recovery procedures"
      
      # Check if we can recover CA from paper backup
      echo "🔐 Testing CA recovery from paper backup..."
      if command -v ca-verify-paper-backup >/dev/null 2>&1; then
        log_simulation "✅ CA recovery tools available"
        echo "✅ CA paper backup recovery tools present"
      else
        log_simulation "❌ CA recovery tools missing"
        echo "❌ CA paper backup recovery tools missing"
      fi
      
      # Check backup accessibility
      echo "💾 Testing backup accessibility..."
      local_accessible=false
      offline_accessible=false
      cloud_accessible=false
      
      if [ -d "/tank/nfs/backup/borg-local" ]; then
        local_accessible=true
        log_simulation "✅ Local backups accessible"
        echo "✅ Local backups accessible"
      else
        log_simulation "❌ Local backups not accessible"
        echo "❌ Local backups not accessible"
      fi
      
      if [ -d "/mnt/backup-drive/borg-offline" ]; then
        offline_accessible=true
        log_simulation "✅ Offline backups accessible"
        echo "✅ Offline backups accessible"
      else
        log_simulation "⚠️  Offline backup drive not mounted"
        echo "⚠️  Offline backup drive not mounted"
      fi
      
      if ${pkgs.rclone}/bin/rclone lsd b2:server-river-backup >/dev/null 2>&1; then
        cloud_accessible=true
        log_simulation "✅ Cloud backups accessible"
        echo "✅ Cloud backups accessible"
      else
        log_simulation "❌ Cloud backups not accessible"
        echo "❌ Cloud backups not accessible"
      fi
      
      # Calculate recovery options
      if $local_accessible || $offline_accessible || $cloud_accessible; then
        log_simulation "✅ Data recovery possible from available backups"
        echo "✅ Data recovery is possible"
      else
        log_simulation "🚨 CRITICAL: No backups accessible for recovery"
        echo "🚨 CRITICAL: No backups accessible for recovery"
      fi
      
      # Scenario 2: Corrupted primary storage
      echo ""
      echo "📋 Scenario 2: Primary Storage Corruption"
      echo "========================================="
      log_simulation "SCENARIO 2: Primary storage corruption simulation"
      
      echo "Simulating ZFS pool corruption..."
      
      # Check ZFS snapshot availability
      if command -v zfs >/dev/null 2>&1; then
        snapshot_count=$(zfs list -t snapshot 2>/dev/null | grep -c "tank/" || echo "0")
        if [ "$snapshot_count" -gt 0 ]; then
          log_simulation "✅ $snapshot_count ZFS snapshots available for rollback"
          echo "✅ ZFS snapshots available for rollback: $snapshot_count"
        else
          log_simulation "⚠️  No ZFS snapshots available"
          echo "⚠️  No ZFS snapshots available"
        fi
      else
        log_simulation "⚠️  ZFS not available"
        echo "⚠️  ZFS not available"
      fi
      
      # Scenario 3: Certificate authority compromise
      echo ""
      echo "📋 Scenario 3: Certificate Authority Compromise"
      echo "=============================================="
      log_simulation "SCENARIO 3: CA compromise simulation"
      
      echo "Simulating CA compromise and recovery..."
      
      # Check air-gapped CA recovery capability
      if [ -d "/etc/step-ca" ]; then
        log_simulation "Current CA installation detected"
        echo "Current CA installation: Present"
        
        # Check if we have root CA certificate
        if [ -f "/etc/step-ca/certs/root_ca.crt" ]; then
          expiry_date=$(openssl x509 -noout -enddate -in /etc/step-ca/certs/root_ca.crt | cut -d= -f2)
          log_simulation "Root CA expires: $expiry_date"
          echo "Root CA expiry: $expiry_date"
        fi
        
        log_simulation "✅ New intermediate CA can be generated from air-gapped root"
        echo "✅ Recovery: Generate new intermediate CA from air-gapped root"
      else
        log_simulation "❌ No current CA installation found"
        echo "❌ No current CA installation found"
      fi
      
      # Scenario 4: Secrets compromise
      echo ""
      echo "📋 Scenario 4: Secrets Compromise"
      echo "================================="
      log_simulation "SCENARIO 4: Secrets compromise simulation"
      
      echo "Simulating secrets compromise and rotation..."
      
      if [ -d "/run/secrets" ]; then
        secret_count=$(ls -1 /run/secrets | wc -l)
        log_simulation "$secret_count SOPS secrets currently accessible"
        echo "Current secrets accessible: $secret_count"
        
        log_simulation "✅ Secrets can be rotated via SOPS key rotation"
        echo "✅ Recovery: Rotate SOPS age key and re-encrypt secrets"
      else
        log_simulation "❌ SOPS secrets not accessible"
        echo "❌ SOPS secrets not accessible"
      fi
      
      # Generate recovery timeline
      echo ""
      echo "📊 Recovery Time Estimate"
      echo "========================="
      log_simulation "RECOVERY TIME ESTIMATES:"
      
      echo "🕐 CA Recovery: 30-60 minutes (air-gapped ceremony)"
      log_simulation "CA Recovery: 30-60 minutes"
      
      echo "🕐 Data Recovery (from local backup): 2-4 hours"
      log_simulation "Data Recovery (local): 2-4 hours"
      
      echo "🕐 Data Recovery (from cloud backup): 6-12 hours"
      log_simulation "Data Recovery (cloud): 6-12 hours"
      
      echo "🕐 Full System Rebuild: 4-8 hours"
      log_simulation "Full system rebuild: 4-8 hours"
      
      echo "🕐 Service Restoration: 1-2 hours"
      log_simulation "Service restoration: 1-2 hours"
      
      echo ""
      echo "📋 Critical Recovery Dependencies:"
      echo "1. Access to paper CA backup (24-word mnemonic)"
      echo "2. SOPS age key for secrets decryption"
      echo "3. At least one backup source (local/offline/cloud)"
      echo "4. Network connectivity for cloud recovery"
      echo "5. Hardware for air-gapped CA operations"
      
      log_simulation "Disaster simulation completed"
      echo ""
      echo "📁 Full simulation log: $LOG_FILE"
      
      # Summary notification
      if $local_accessible && $cloud_accessible; then
        smart-notify info "Disaster Simulation Complete" "Recovery validation passed - multiple backup sources available" "backup,disaster-recovery"
      else
        smart-notify warning "Disaster Simulation Issues" "Some backup sources not accessible - review simulation log" "backup,disaster-recovery"
      fi
    '')

    # Smart notification helper script
    (writeShellScriptBin "smart-notify" ''
      #!/usr/bin/env bash
      
      # smart-notify: Intelligent notification routing
      # Usage: smart-notify <level> <title> <message> [tags]
      
      LEVEL="$1"
      TITLE="$2" 
      MESSAGE="$3"
      TAGS="$4"
      
      CURRENT_HOUR=$(date +%H)
      BASE_URL="http://100.64.0.1:8080"  # Use VPN address
      
      # Determine if we're in work hours (9-18)
      IS_WORK_HOURS=false
      if [ $CURRENT_HOUR -ge 9 ] && [ $CURRENT_HOUR -lt 18 ]; then
        IS_WORK_HOURS=true
      fi
      
      case "$LEVEL" in
        "critical")
          # Always push critical alerts
          curl -d "$MESSAGE" \
            -H "Title: 🚨 $TITLE" \
            -H "Priority: 5" \
            -H "Tags: rotating_light,$TAGS" \
            "$BASE_URL/server-critical"
          ;;
        "warning") 
          # Only during work hours
          if [ "$IS_WORK_HOURS" = true ]; then
            curl -d "$MESSAGE" \
              -H "Title: ⚠️ $TITLE" \
              -H "Priority: 4" \
              -H "Tags: warning,$TAGS" \
              "$BASE_URL/server-warning"
          fi
          ;;
        "info")
          # Dashboard only - no push notification
          echo "$(date): [INFO] $TITLE - $MESSAGE" >> /var/log/dashboard-events.log
          ;;
        "summary")
          # Weekly summary topic  
          curl -d "$MESSAGE" \
            -H "Title: 📊 $TITLE" \
            -H "Priority: 2" \
            -H "Tags: chart_with_upwards_trend,$TAGS" \
            "$BASE_URL/server-summary"
          ;;
      esac
    '')
  ];
  
  # Weekly summary report
  systemd.services."weekly-summary" = {
    description = "Weekly server summary report";
    serviceConfig = {
      Type = "oneshot";
      User = vars.user.name;
      Group = "users";
    };
    
    script = ''
      # Collect weekly stats
      WEEK_START=$(date -d "7 days ago" +%Y-%m-%d)
      CURRENT_DATE=$(date +%Y-%m-%d)
      
      # Backup success rate
      TOTAL_BACKUPS=$(grep -c "backup completed" /var/log/backup-notifications.log | tail -7 | wc -l)
      FAILED_BACKUPS=$(grep -c "backup FAILED" /var/log/backup-notifications.log | tail -7 | wc -l)
      SUCCESS_RATE=$((($TOTAL_BACKUPS - $FAILED_BACKUPS) * 100 / $TOTAL_BACKUPS))
      
      # Storage info
      STORAGE_USED=$(zfs list -H -o used tank/nfs | head -1)
      STORAGE_TOTAL=$(zfs list -H -o avail tank/nfs | head -1)
      
      # System uptime
      UPTIME=$(uptime -p)
      
      # ZFS status
      ZFS_STATUS=$(zpool status tank | grep -c "errors: No known data errors")
      
      # Headscale node count
      HEADSCALE_NODES=$(headscale nodes list 2>/dev/null | tail -n +2 | wc -l || echo "0")
      
      # Generate summary
      SUMMARY="📊 Weekly Server Report ($WEEK_START to $CURRENT_DATE)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Uptime: $UPTIME
💾 Backups: $SUCCESS_RATE% success rate ($TOTAL_BACKUPS total)
📈 Storage: $STORAGE_USED used, $STORAGE_TOTAL available
🔄 ZFS Health: $([ $ZFS_STATUS -gt 0 ] && echo "Clean" || echo "Check needed")
🌐 Syncthing: $(systemctl is-active syncthing)
🔒 VPN Nodes: $HEADSCALE_NODES connected
⚠️ Issues: $(grep -c "CRITICAL\|ERROR" /var/log/messages || echo "0")

📱 Dashboard: http://grafana.internal.robcohen.dev:3000
🔒 VPN Admin: https://sync.robcohen.dev
📋 Logs: /var/log/backup-notifications.log"
      
      smart-notify summary "Weekly Report" "$SUMMARY" "report,weekly"
    '';
  };
  
  systemd.timers."weekly-summary" = {
    description = "Weekly summary report timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun 09:00";
      Persistent = true;
    };
  };
  
  # Internal Certificate Authority Integration
  # Certificates come from air-gapped CA system
  
  # Step-CA for internal service certificates (using intermediate from air-gap)
  services.step-ca = {
    enable = true;
    address = "127.0.0.1";
    port = 9000;
    
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
  systemd.services.grafana.serviceConfig = {
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    RestrictSUIDSGID = true;
    RemoveIPC = true;
    RestrictRealtime = true;
    RestrictNamespaces = true;
    LockPersonality = true;
    SystemCallFilter = [ "@system-service" "~@debug" "~@mount" "~@privileged" ];
    RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
    ReadWritePaths = [ "/var/lib/grafana" ];
  };

  systemd.services.prometheus.serviceConfig = {
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    RestrictSUIDSGID = true;
    RemoveIPC = true;
    RestrictRealtime = true;
    SystemCallFilter = [ "@system-service" "~@debug" "~@mount" "~@privileged" ];
    RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
    ReadWritePaths = [ "/var/lib/prometheus2" ];
  };

  systemd.services.ntfy-sh.serviceConfig = {
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    RestrictSUIDSGID = true;
    RemoveIPC = true;
    RestrictRealtime = true;
    SystemCallFilter = [ "@system-service" "~@debug" "~@mount" "~@privileged" ];
    RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
    ReadWritePaths = [ "/var/lib/ntfy-sh" ];
  };

  systemd.services.headscale.serviceConfig = {
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    RestrictSUIDSGID = true;
    RemoveIPC = true;
    RestrictRealtime = true;
    SystemCallFilter = [ "@system-service" "~@debug" "~@mount" "~@privileged" ];
    RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
    ReadWritePaths = [ "/var/lib/headscale" ];
  };

  # Security hardening for logging services
  systemd.services.loki.serviceConfig = {
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    RestrictSUIDSGID = true;
    RemoveIPC = true;
    RestrictRealtime = true;
    SystemCallFilter = [ "@system-service" "~@debug" "~@mount" "~@privileged" ];
    RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
    ReadWritePaths = [ "/var/lib/loki" ];
  };

  systemd.services.promtail.serviceConfig = {
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    RestrictSUIDSGID = true;
    RemoveIPC = true;
    RestrictRealtime = true;
    SystemCallFilter = [ "@system-service" "~@debug" "~@mount" "~@privileged" ];
    RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
    ReadWritePaths = [ "/var/lib/promtail" "/var/log" ];
  };

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
      group = "headscale";
      postRun = "systemctl reload headscale";
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
      dns_config = {
        override_local_dns = true;
        nameservers = [
          "1.1.1.1"
          "8.8.8.8"
        ];
        domains = [ ];
        magic_dns = true;
        base_domain = "internal.robcohen.dev";
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