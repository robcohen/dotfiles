# Installation Guide

Complete guide for installing NixOS using this configuration, from bare metal to a working system.

## Prerequisites

- USB drive (8GB+) for installation media
- Target machine with UEFI boot support
- Network connection (Ethernet recommended for initial install)
- Another device to read this guide during installation

## Step 1: Create Installation Media

### Option A: Use the Emergency ISO (Recommended)

Build the emergency ISO with your SSH key for remote installation:

```bash
# On an existing NixOS/Nix system
EMERGENCY_SSH_KEY="ssh-ed25519 AAAA... your-key" nix build .#emergency-iso

# Write to USB (replace /dev/sdX with your USB device)
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress
```

### Option B: Use Official NixOS ISO

Download from [nixos.org/download](https://nixos.org/download.html) and write to USB.

## Step 2: Boot and Prepare

1. Boot from USB (usually F12/F2/Del for boot menu)
2. Connect to network:

```bash
# Wired (usually automatic)
ip a  # Check for IP address

# WiFi
nmcli device wifi list
nmcli device wifi connect "SSID" password "password"
```

3. Enable SSH for remote installation (optional but recommended):

```bash
# Set root password for SSH access
passwd

# Start SSH
systemctl start sshd

# Get IP address
ip a | grep inet
```

Now you can SSH in from another machine for easier copy/paste.

## Step 3: Partition Disks with Disko

This configuration uses Disko for declarative disk partitioning.

### Identify Your Disk

```bash
# List disks
lsblk -d -o NAME,SIZE,MODEL

# Usually /dev/nvme0n1 for NVMe or /dev/sda for SATA
```

### Run Disko

```bash
# Clone the repository
git clone https://github.com/YOUR-USERNAME/dotfiles.git /tmp/dotfiles
cd /tmp/dotfiles

# Edit disko.nix if needed (check device path)
nano hosts/snix/disko.nix
# Verify: device = "/dev/nvme0n1"; matches your disk

# Run disko (DESTRUCTIVE - erases disk!)
sudo nix run github:nix-community/disko -- --mode disko ./hosts/snix/disko.nix
```

Disko will:
1. Create GPT partition table
2. Create ESP (1GB), swap (32GB), and root partitions
3. Set up LUKS2 encryption (you'll be prompted for passphrase)
4. Create btrfs subvolumes
5. Mount everything to /mnt

### Verify Mounts

```bash
# Check mounts
mount | grep /mnt

# Should see:
# /dev/mapper/cryptroot on /mnt type btrfs (subvol=@root)
# /dev/mapper/cryptroot on /mnt/home type btrfs (subvol=@home)
# /dev/mapper/cryptroot on /mnt/nix type btrfs (subvol=@nix)
# etc.
```

## Step 4: Generate Hardware Configuration

```bash
# Generate hardware config for the mounted system
sudo nixos-generate-config --root /mnt

# This creates:
# /mnt/etc/nixos/configuration.nix (we'll replace this)
# /mnt/etc/nixos/hardware-configuration.nix (keep this)
```

## Step 5: Clone Configuration

```bash
# Clone to target system
sudo git clone https://github.com/YOUR-USERNAME/dotfiles.git /mnt/home/user/dotfiles

# Copy generated hardware config
sudo cp /mnt/etc/nixos/hardware-configuration.nix /mnt/home/user/dotfiles/hosts/snix/
```

## Step 6: Install NixOS

```bash
# Install with flake
sudo nixos-install --flake /mnt/home/user/dotfiles#snix

# You'll be prompted to set root password
# For user password, either:
# 1. Set via SOPS after first boot
# 2. Use environment variable during install:
#    USER_PASSWORD_HASH="$(mkpasswd -m sha-512)" sudo nixos-install --flake ...
```

## Step 7: First Boot

1. Reboot and remove USB
2. Enter LUKS passphrase at boot
3. Log in (if password was set) or use SSH with your key

## Step 8: Post-Installation Setup

### Set Up Secrets (SOPS)

```bash
cd ~/dotfiles

# Bootstrap secrets with BIP39 mnemonic
./assets/scripts/bootstrap-secrets.sh --generate

# IMPORTANT: Write down the 24-word mnemonic!
# Store it securely offline - this is your master key
```

### Apply Home Manager

```bash
# Apply user configuration
home-manager switch --flake ~/dotfiles#user@snix
```

### Set User Password (if not done during install)

```bash
# Option 1: Set password directly
passwd user

# Option 2: Configure via SOPS (recommended)
# Edit secrets and add user/hashedPassword
sops ~/.secrets/secrets.yaml
```

## Step 9: Verify Installation

```bash
# Check system status
systemctl --failed

# Verify TPM
tpm-keys list

# Check network
ping -c 3 nixos.org

# Verify graphics
glxinfo | grep "OpenGL renderer"
```

## Troubleshooting Installation

### Disko fails with "device busy"

```bash
# Unmount all partitions
umount -R /mnt
swapoff -a
cryptsetup close cryptroot
```

### LUKS passphrase not accepted at boot

- Verify keyboard layout (US QWERTY during boot)
- Check if you're using special characters that differ between layouts

### Network not working after install

```bash
# Check if NetworkManager is running
systemctl status NetworkManager

# Manually connect
nmcli device wifi connect "SSID" password "password"
```

### Boot fails with "no bootable device"

- Enter BIOS and ensure UEFI boot is enabled
- Check Secure Boot is disabled (until lanzaboote is configured)
- Verify ESP is mounted at /boot and has EFI files

## Alternative: Installing Without Disko

If you prefer manual partitioning:

```bash
# Create partitions manually with fdisk/parted
# Then mount to /mnt following the expected layout

# Skip disko.nix import in configuration.nix
# Use generated hardware-configuration.nix as-is
```

## Next Steps

- Read [ARCHITECTURE.md](ARCHITECTURE.md) to understand the configuration structure
- Configure additional hosts by copying and modifying snix/
- Set up CI/CD for automated testing (future)
- Configure Secure Boot with lanzaboote (future)
