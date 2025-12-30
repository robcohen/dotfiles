# Troubleshooting Guide

Common issues and their solutions when working with this NixOS configuration.

## Build Errors

### "error: attribute 'X' missing"

**Cause**: Missing input or module not imported.

**Solution**:
```bash
# Update flake lock
nix flake update

# Check if module is imported in configuration
grep -r "X" hosts/*/configuration.nix
```

### "infinite recursion encountered"

**Cause**: Circular dependency in module imports or option definitions.

**Solution**:
1. Check recent changes for circular imports
2. Use `lib.mkDefault` or `lib.mkForce` to break cycles
3. Move option definitions to separate modules

### "error: collision between X and Y"

**Cause**: Same file/package defined multiple times.

**Solution**:
```nix
# Use lib.mkForce to override
environment.systemPackages = lib.mkForce [ ... ];

# Or use priority
lib.mkOverride 100 [ ... ];
```

### Build runs out of memory

**Solution**:
```bash
# Increase swap or use remote builder
# Or build with reduced parallelism
nix build --cores 2 --max-jobs 1 .#host
```

## Boot Issues

### LUKS passphrase not accepted

**Causes**:
- Keyboard layout differs at boot (US QWERTY vs your layout)
- Special characters typed incorrectly

**Solutions**:
1. Use only ASCII characters in passphrase
2. Check keyboard layout in BIOS
3. Boot from live USB and verify passphrase:
   ```bash
   cryptsetup open /dev/nvme0n1p3 cryptroot
   ```

### "No bootable device found"

**Solutions**:
1. Enter BIOS and enable UEFI boot
2. Disable Secure Boot (until lanzaboote is configured)
3. Verify ESP has correct structure:
   ```bash
   ls /boot/EFI/systemd/
   # Should contain: systemd-bootx64.efi
   ```

### Boot hangs at Plymouth

**Solution**:
```bash
# Boot with kernel parameters to debug
# At boot menu, press 'e' and add:
systemd.log_level=debug rd.shell

# Or disable Plymouth temporarily
boot.plymouth.enable = false;
```

### System boots to black screen

**Cause**: Graphics driver issue.

**Solution**:
1. Boot with `nomodeset` kernel parameter
2. SSH in and check logs:
   ```bash
   journalctl -b -p err
   ```
3. Verify graphics configuration:
   ```nix
   hardware.graphics.enable = true;
   boot.initrd.kernelModules = [ "amdgpu" ]; # or "i915" for Intel
   ```

## Network Issues

### WiFi not connecting

**Solutions**:
```bash
# Check device status
nmcli device status

# Rescan networks
nmcli device wifi rescan

# Connect manually
nmcli device wifi connect "SSID" password "password"

# Check for driver issues
dmesg | grep -i wifi
journalctl -b | grep -i networkmanager
```

### Tailscale not connecting

**Solutions**:
```bash
# Check status
tailscale status

# Re-authenticate
tailscale up --reset

# Check for firewall issues
sudo iptables -L -n | grep -i tailscale
```

### DNS not resolving

**Solutions**:
```bash
# Check resolv.conf
cat /etc/resolv.conf

# Test with specific DNS
nslookup example.com 1.1.1.1

# Restart resolved
systemctl restart systemd-resolved
```

## Secrets / SOPS Issues

### "sops-nix: secret not found"

**Cause**: Secret not defined in secrets.yaml or path mismatch.

**Solution**:
```bash
# Verify secret exists
sops ~/.secrets/secrets.yaml
# Check the key path matches what's defined in modules/sops.nix
```

### "age: no identity matched"

**Cause**: Age key not available or wrong key.

**Solution**:
```bash
# Check age key exists
ls -la /var/lib/sops-nix/key.txt

# Verify key matches .sops.yaml
cat ~/.sops.yaml
# age key should match key in /var/lib/sops-nix/key.txt

# Re-encrypt secrets with correct key
sops updatekeys ~/.secrets/secrets.yaml
```

### "Permission denied" for secrets

**Cause**: Secret file permissions or ownership.

**Solution**:
```bash
# Check permissions
ls -la /run/secrets/

# Verify in configuration
sops.secrets."mykey" = {
  owner = "myuser";
  group = "users";
  mode = "0400";
};
```

## TPM Issues

### "TPM device not found"

**Solutions**:
1. Enable TPM in BIOS
2. Check kernel module:
   ```bash
   lsmod | grep tpm
   dmesg | grep -i tpm
   ```
3. Verify device exists:
   ```bash
   ls /dev/tpm*
   ```

### "tpm2_createprimary failed"

**Cause**: TPM hierarchy locked or permissions issue.

**Solutions**:
```bash
# Check TPM status
tpm2_getcap properties-fixed

# Clear TPM (WARNING: destroys all keys!)
# Only do this if you have your BIP39 mnemonic backed up
# tpm2_clear

# Re-initialize
sudo tpm-init --force
```

### TPM keys not persisting

**Cause**: Keys created in volatile storage.

**Solution**: Ensure keys are made persistent:
```bash
tpm2_evictcontrol -C o -c key.ctx 0x81000001
```

## Home Manager Issues

### "collision between /nix/store/X and /nix/store/Y"

**Cause**: Multiple packages providing same file.

**Solution**:
```nix
# In home.nix, use allowUnfree or exclude conflicting package
home.packages = with pkgs; [
  (package1.override { ... })
];
```

### Home Manager not applying changes

**Solutions**:
```bash
# Force rebuild
home-manager switch --flake .#user@host -b backup

# Check for errors
home-manager build --flake .#user@host

# Clear old generations
home-manager expire-generations "-7 days"
```

### "Could not find suitable profile directory"

**Cause**: Home Manager profile not created.

**Solution**:
```bash
# Create profile link
mkdir -p ~/.local/state/nix/profiles
```

## Performance Issues

### System slow after rebuild

**Solutions**:
```bash
# Check for failing services
systemctl --failed

# Check resource usage
htop
iotop

# Check if nix-daemon is building
ps aux | grep nix
```

### Nix store growing too large

**Solutions**:
```bash
# Garbage collect
nix-collect-garbage -d

# Remove old generations
sudo nix-collect-garbage --delete-older-than 30d

# Optimize store
nix-store --optimise
```

## Development Shell Issues

### "direnv: error .envrc"

**Solutions**:
```bash
# Allow the directory
direnv allow

# Check for syntax errors
cat .envrc

# Reload
direnv reload
```

### Shell missing packages

**Cause**: devShell not loaded or wrong shell.

**Solution**:
```bash
# Enter shell explicitly
nix develop

# Or with direnv
echo "use flake" > .envrc
direnv allow
```

## Debugging Tips

### Enable verbose output

```bash
# NixOS rebuild
sudo nixos-rebuild switch --flake .#host --show-trace

# Home Manager
home-manager switch --flake .#user@host --show-trace

# Nix build
nix build --show-trace -L .#package
```

### Check evaluation

```bash
# Test flake evaluation without building
nix flake check --no-build

# Show flake outputs
nix flake show
```

### Bisect configuration changes

```bash
# Check git history
git log --oneline

# Test specific commit
git checkout <commit>
sudo nixos-rebuild build --flake .#host
```

### Read systemd logs

```bash
# Current boot
journalctl -b

# Specific service
journalctl -u servicename

# Follow live
journalctl -f
```

## Getting Help

1. Check NixOS options: `man configuration.nix` or [search.nixos.org/options](https://search.nixos.org/options)
2. Search packages: [search.nixos.org/packages](https://search.nixos.org/packages)
3. NixOS Discourse: [discourse.nixos.org](https://discourse.nixos.org)
4. NixOS Matrix: `#nixos:nixos.org`

When reporting issues, include:
- Output of `nix flake metadata`
- Relevant configuration snippets (sanitized)
- Full error message with `--show-trace`
