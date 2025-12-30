# modules/virtualization.nix
# Consolidated virtualization module for all hosts
#
# Features:
# - libvirt/QEMU with virt-manager
# - Podman with Docker compatibility
# - Waydroid (Android containers)
# - GPU passthrough (VFIO/KVMFR) for Looking Glass
# - macOS VM support via OSX-KVM
# - MicroVMs (cloud-hypervisor/firecracker) for ephemeral security testing
#
# Usage:
#   virtualization.vms.enable = true;
#   virtualization.vms.podman.enable = true;
#   virtualization.vms.waydroid.enable = true;
#   virtualization.vms.gpuPassthrough.enable = true;  # For GPU passthrough
#   virtualization.vms.macos.enable = true;           # For macOS VMs
#   virtualization.vms.microvm.enable = true;         # For ephemeral microVMs
#   virtualization.vms.microvm.rednix.enable = true;  # RedNix security VM
{
  config,
  lib,
  pkgs,
  rednix ? null,
  ...
}:

let
  cfg = config.virtualization.vms;
in
{
  options.virtualization.vms = {
    enable = lib.mkEnableOption "VM support with libvirt/QEMU and virt-manager";

    user = lib.mkOption {
      type = lib.types.str;
      default = "user";
      description = "Primary user to add to virtualization groups";
    };

    # =========================================================================
    # Waydroid (Android)
    # =========================================================================
    waydroid.enable = lib.mkEnableOption "Waydroid Android container support";

    # =========================================================================
    # Podman / Containers
    # =========================================================================
    podman = {
      enable = lib.mkEnableOption "Podman container runtime with Docker compatibility";

      autoPrune = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable automatic weekly container pruning";
        };
      };
    };

    # =========================================================================
    # GPU Passthrough (VFIO / KVMFR / Looking Glass)
    # =========================================================================
    gpuPassthrough = {
      enable = lib.mkEnableOption "GPU passthrough with VFIO and KVMFR for Looking Glass";

      gpuIds = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "10de:2504,10de:228e";
        description = "Comma-separated PCI IDs for GPU passthrough";
      };

      kvmfrSizeMb = lib.mkOption {
        type = lib.types.int;
        default = 128;
        description = "KVMFR shared memory size in MB for Looking Glass";
      };

      iommu = lib.mkOption {
        type = lib.types.enum [ "intel" "amd" ];
        default = "intel";
        description = "IOMMU type based on CPU vendor";
      };

      blacklistDrivers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "nvidia" "nouveau" ];
        description = "Kernel modules to blacklist for GPU passthrough";
      };
    };

    # =========================================================================
    # macOS VM Support
    # =========================================================================
    macos = {
      enable = lib.mkEnableOption "macOS VM support via OSX-KVM";
    };

    # =========================================================================
    # MicroVM Support (ephemeral VMs via cloud-hypervisor/firecracker)
    # =========================================================================
    microvm = {
      enable = lib.mkEnableOption "MicroVM host support for ephemeral VMs";

      hypervisor = lib.mkOption {
        type = lib.types.enum [ "cloud-hypervisor" "firecracker" "qemu" "crosvm" ];
        default = "cloud-hypervisor";
        description = "Default hypervisor for microVMs";
      };

      rednix = {
        enable = lib.mkEnableOption "RedNix ephemeral security/pentesting VM";

        memory = lib.mkOption {
          type = lib.types.int;
          default = 2049;  # Avoid exactly 2GB due to QEMU bug
          description = "Memory allocation in MB for RedNix VM";
        };

        cores = lib.mkOption {
          type = lib.types.int;
          default = 2;
          description = "Number of CPU cores for RedNix VM";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # =========================================================================
    # Base libvirt/QEMU configuration (always enabled with vms.enable)
    # =========================================================================
    {
      virtualisation.libvirtd = {
        enable = true;
        allowedBridges = [ "virbr0" ];
        qemu = {
          package = pkgs.qemu_kvm;
          swtpm.enable = true; # TPM emulation for Windows 11, etc.
          runAsRoot = lib.mkDefault false;
        };
      };

      programs.virt-manager.enable = true;

      # Networking for libvirt
      networking.firewall.trustedInterfaces = [ "virbr0" ];

      # User groups for VM access
      users.groups.libvirtd.members = [ cfg.user ];
      users.groups.kvm.members = [ cfg.user ];

      # Useful packages for VM management
      environment.systemPackages = with pkgs; [
        virt-viewer
        spice-gtk
      ];
    }

    # =========================================================================
    # Podman configuration
    # =========================================================================
    (lib.mkIf cfg.podman.enable {
      virtualisation.podman = {
        enable = true;
        dockerCompat = true;
        dockerSocket.enable = true;
        defaultNetwork.settings = {
          dns_enabled = true;
          ipv6_enabled = false;
        };
      };

      virtualisation.podman.autoPrune = lib.mkIf cfg.podman.autoPrune.enable {
        enable = true;
        dates = "weekly";
        flags = [ "--all" ];
      };

      # Container registry mirrors
      virtualisation.containers.registries.search = [
        "docker.io"
        "quay.io"
        "ghcr.io"
      ];

      environment.systemPackages = with pkgs; [
        podman-compose
      ];
    })

    # =========================================================================
    # Waydroid configuration
    # =========================================================================
    (lib.mkIf cfg.waydroid.enable {
      virtualisation.waydroid.enable = true;
      users.users.${cfg.user}.extraGroups = [ "adbusers" ];
      programs.adb.enable = true;
    })

    # =========================================================================
    # GPU Passthrough configuration (VFIO / KVMFR)
    # =========================================================================
    (lib.mkIf cfg.gpuPassthrough.enable {
      # Kernel modules for VFIO
      boot.extraModulePackages = with config.boot.kernelPackages; [ kvmfr ];
      boot.kernelModules = [
        "kvmfr"
        "vfio_virqfd"
        "vfio_pci"
        "vfio_iommu_type1"
        "vfio"
      ];

      # Blacklist GPU drivers
      boot.blacklistedKernelModules = cfg.gpuPassthrough.blacklistDrivers;

      # Module options
      boot.extraModprobeConfig = ''
        options kvmfr static_size_mb=${toString cfg.gpuPassthrough.kvmfrSizeMb}
        ${lib.optionalString (cfg.gpuPassthrough.gpuIds != "") "options vfio-pci ids=${cfg.gpuPassthrough.gpuIds}"}
      '';

      # IOMMU
      boot.kernelParams = [
        "${cfg.gpuPassthrough.iommu}_iommu=on"
      ];

      # Udev rules for KVMFR and VFIO device access
      services.udev.extraRules = ''
        SUBSYSTEM=="kvmfr", OWNER="${cfg.user}", GROUP="kvm", MODE="0660"
        SUBSYSTEM=="vfio", OWNER="${cfg.user}", GROUP="kvm", MODE="0660"
      '';

      # Looking Glass client
      environment.systemPackages = with pkgs; [
        looking-glass-client
      ];
    })

    # =========================================================================
    # macOS VM configuration
    # =========================================================================
    (lib.mkIf cfg.macos.enable {
      # Required packages for OSX-KVM
      environment.systemPackages = with pkgs; [
        qemu_kvm
        dmg2img # Convert DMG to IMG
        p7zip # Extract installers
        wget
        cdrkit # For creating ISO images
      ];

      # QEMU needs to emulate certain Apple hardware
      boot.extraModprobeConfig = lib.mkAfter ''
        # macOS requires specific QEMU CPU flags
        options kvm ignore_msrs=1
        options kvm report_ignored_msrs=0
      '';

      # Libvirt hooks directory for macOS-specific setup
      systemd.tmpfiles.rules = [
        "d /var/lib/libvirt/images/macos 0755 ${cfg.user} libvirt-qemu -"
      ];
    })

    # =========================================================================
    # MicroVM host configuration
    # =========================================================================
    (lib.mkIf cfg.microvm.enable {
      # Install hypervisor packages
      environment.systemPackages = with pkgs; [
        cloud-hypervisor
        firectl
        virtiofsd
        socat  # For console access
      ];

      # Enable microvm host
      microvm.host.enable = true;
    })

    # =========================================================================
    # RedNix ephemeral security VM (simple QEMU-based)
    # =========================================================================
    (lib.mkIf (cfg.microvm.enable && cfg.microvm.rednix.enable) {
      microvm.vms.rednix = {
        autostart = false;
        flake = null;
        inherit pkgs;

        config = {
          microvm = {
            # Use QEMU - simpler networking
            hypervisor = "qemu";
            mem = cfg.microvm.rednix.memory;
            vcpu = cfg.microvm.rednix.cores;

            # User-mode networking - no tap/bridge needed
            interfaces = [{
              type = "user";
              id = "net0";
              mac = "02:00:00:00:00:01";
            }];

            # Share host's nix store
            shares = [{
              tag = "ro-store";
              source = "/nix/store";
              mountPoint = "/nix/.ro-store";
              proto = "virtiofs";
            }];

            # Ephemeral
            volumes = [];
            writableStoreOverlay = "/nix/.rw-store";
          };

          system.stateVersion = "24.05";
          networking.hostName = "rednix";
          networking.firewall.enable = false;

          # Ephemeral VM - autologin to root, no password needed
          # This VM is destroyed after each use, so no password is necessary
          services.getty.autologinUser = "root";

          environment.systemPackages = with pkgs; [
            nmap wireshark-cli tcpdump netcat-gnu
            curl wget httpie
            metasploit gobuster ffuf
            binwalk foremost
            john hashcat
            vim tmux git jq file unzip
          ];
        };
      };

      # Simple launcher
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "rednix" ''
          case "''${1:-run}" in
            run|start)
              echo "Starting RedNix VM (Ctrl+A X to exit)..."
              sudo systemctl start microvm@rednix.service
              sleep 2
              sudo journalctl -fu microvm@rednix.service
              ;;
            stop)
              sudo systemctl stop microvm@rednix.service
              ;;
            status)
              systemctl status microvm@rednix.service
              ;;
            *)
              echo "Usage: rednix [run|stop|status]"
              ;;
          esac
        '')
      ];
    })
  ]);
}
