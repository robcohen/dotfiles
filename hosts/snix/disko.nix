# hosts/snix/disko.nix
# Declarative disk partitioning for snix (AMD laptop)
#
# This configuration defines the complete disk layout for fresh installations.
# It uses LUKS2 encryption with btrfs subvolumes for flexibility and snapshots.
#
# Usage:
#   # Format and mount (DESTRUCTIVE - erases all data!)
#   sudo nix run github:nix-community/disko -- --mode disko ./hosts/snix/disko.nix
#
#   # Or with the flake:
#   sudo nix run github:nix-community/disko -- --mode disko --flake .#snix
#
# Partition layout:
#   /dev/nvme0n1p1 - 1GB   - ESP (FAT32) - /boot
#   /dev/nvme0n1p2 - 32GB  - Swap (encrypted)
#   /dev/nvme0n1p3 - Rest  - LUKS2 → btrfs - /
#
# Btrfs subvolumes:
#   @root     → /
#   @home     → /home
#   @nix      → /nix
#   @persist  → /persist (for impermanence, future use)
#   @log      → /var/log
#   @snapshots → /.snapshots
#
{ lib, ... }:
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # Target device - update this for your hardware
        # Use: lsblk -d -o NAME,SIZE,MODEL to find your NVMe
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            # EFI System Partition
            ESP = {
              size = "1G";
              type = "EF00"; # EFI System
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "fmask=0077"
                  "dmask=0077"
                  "defaults"
                ];
              };
            };

            # Swap partition (encrypted via initrd)
            swap = {
              size = "32G";
              content = {
                type = "swap";
                randomEncryption = true;
                # For hibernation, use a fixed key instead:
                # resumeDevice = true;
              };
            };

            # Main encrypted partition
            root = {
              size = "100%"; # Use remaining space
              content = {
                type = "luks";
                name = "cryptroot";
                # LUKS2 with strong defaults
                settings = {
                  allowDiscards = true; # Enable TRIM for SSD
                  bypassWorkqueues = true; # Better SSD performance
                };
                # Password will be prompted during installation
                # For TPM unlock, configure after install:
                #   systemd-cryptenroll --tpm2-device=auto /dev/nvme0n1p3
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" "-L" "nixos" ]; # Force, with label
                  subvolumes = {
                    # Root subvolume
                    "@root" = {
                      mountpoint = "/";
                      mountOptions = [
                        "compress=zstd:1"
                        "noatime"
                        "ssd"
                        "discard=async"
                      ];
                    };

                    # Home - user data
                    "@home" = {
                      mountpoint = "/home";
                      mountOptions = [
                        "compress=zstd:1"
                        "noatime"
                        "ssd"
                        "discard=async"
                      ];
                    };

                    # Nix store - benefits from compression
                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = [
                        "compress=zstd:1"
                        "noatime"
                        "ssd"
                        "discard=async"
                      ];
                    };

                    # Persistence directory (for future impermanence)
                    "@persist" = {
                      mountpoint = "/persist";
                      mountOptions = [
                        "compress=zstd:1"
                        "noatime"
                        "ssd"
                        "discard=async"
                      ];
                    };

                    # Logs - separate for easy management
                    "@log" = {
                      mountpoint = "/var/log";
                      mountOptions = [
                        "compress=zstd:1"
                        "noatime"
                        "ssd"
                        "discard=async"
                      ];
                    };

                    # Snapshots directory
                    "@snapshots" = {
                      mountpoint = "/.snapshots";
                      mountOptions = [
                        "compress=zstd:1"
                        "noatime"
                        "ssd"
                        "discard=async"
                      ];
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
