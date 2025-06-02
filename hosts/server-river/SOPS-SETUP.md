# SOPS (Secrets OPerationS) Setup for Server-River

This document outlines the setup procedures for SOPS-based secret management using age encryption.

## Prerequisites

- NixOS system with sops-nix configured
- Administrative access to the server
- Network access for initial setup

## 1. Age Key Generation

### Generate Age Key Pair

```bash
# Install age (if not already available)
nix-shell -p age

# Create sops directory
mkdir -p ~/.config/sops/age

# Generate new age key
age-keygen -o ~/.config/sops/age/keys.txt

# Display the public key (needed for .sops.yaml)
grep "# public key:" ~/.config/sops/age/keys.txt
```

### Secure the Private Key

```bash
# Set proper permissions
chmod 600 ~/.config/sops/age/keys.txt
chmod 700 ~/.config/sops/age

# Backup the key securely (store offline)
cp ~/.config/sops/age/keys.txt ~/age-key-backup-$(date +%Y%m%d).txt

# Create system-wide key for sops-nix
sudo mkdir -p /var/lib/sops-nix
sudo cp ~/.config/sops/age/keys.txt /var/lib/sops-nix/key.txt
sudo chmod 600 /var/lib/sops-nix/key.txt
sudo chown root:root /var/lib/sops-nix/key.txt
```

## 2. Configure SOPS for the Repository

### Create .sops.yaml Configuration

```bash
# In the dotfiles root directory
cd /home/user/Documents/dotfiles
```

Create `.sops.yaml`:
```yaml
keys:
  - &server-river age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx  # Replace with your public key
creation_rules:
  - path_regex: hosts/server-river/secrets\.yaml$
    key_groups:
    - age:
      - *server-river
  - path_regex: hosts/.*/secrets\.yaml$
    key_groups:
    - age:
      - *server-river
```

## 3. Initialize Secrets File

### Method 1: Create New Secrets File

```bash
cd /home/user/Documents/dotfiles/hosts/server-river

# Install sops
nix-shell -p sops

# Create/edit secrets file (will use age key automatically)
sops secrets.yaml
```

### Method 2: Update Existing Template

If `secrets.yaml` already exists as a template:

```bash
# Backup the template
cp secrets.yaml secrets-template.yaml

# Edit with sops (will encrypt placeholders)
sops secrets.yaml
```

## 4. Secret Values to Configure

When editing `secrets.yaml` with SOPS, provide real values for:

### Certificate Authority
```yaml
ca-intermediate-passphrase: "your-ca-passphrase-here"
```

### ACME / Let's Encrypt
```yaml
cloudflare-api-key: "your-cloudflare-api-key"
```

### Backup Encryption
```yaml
borg-passphrase: "strong-borg-backup-passphrase"
borg-passphrase-offline: "different-strong-offline-passphrase"
```

### Backblaze B2 (dotenv format)
```yaml
backblaze-env: |
    B2_ACCOUNT_ID=your_b2_account_id
    B2_APPLICATION_KEY=your_b2_application_key
```

### Grafana
```yaml
grafana-admin-password: "secure-admin-password"
```

### Headscale VPN
```yaml
headscale-private-key: "generated-headscale-private-key"
```

## 5. Service-Specific Secret Generation

### Headscale Private Key

```bash
# Generate headscale private key
nix-shell -p headscale --run "headscale gen-key"
# Copy the generated key to clipboard and paste into secrets.yaml
```

### Borg Passphrases

```bash
# Generate strong passphrases
openssl rand -base64 32  # For borg-passphrase
openssl rand -base64 32  # For borg-passphrase-offline
```

### Grafana Admin Password

```bash
# Generate secure admin password
openssl rand -base64 24
```

## 6. Verify Secret Decryption

### Test Secret Access

```bash
# Test decrypting a specific secret
sops -d secrets.yaml | grep "borg-passphrase:"

# Test that sops-nix can access secrets (after NixOS rebuild)
sudo cat /run/secrets/borg-passphrase
sudo cat /run/secrets/grafana-admin-password
```

### Check Secret Permissions

```bash
# Verify secret file permissions
ls -la /run/secrets/

# Should show proper ownership as configured in configuration.nix
# Example:
# -r--------  1 root     users     32 Dec  1 12:00 borg-passphrase
# -r--------  1 grafana  grafana   24 Dec  1 12:00 grafana-admin-password
```

## 7. Secret Rotation Procedures

### Rotate Age Key

```bash
# Generate new age key
age-keygen -o ~/.config/sops/age/keys-new.txt

# Add new key to .sops.yaml
# Re-encrypt secrets with new key
sops updatekeys secrets.yaml

# Deploy new key to server
sudo cp ~/.config/sops/age/keys-new.txt /var/lib/sops-nix/key.txt

# Rebuild NixOS configuration
sudo nixos-rebuild switch --flake .#server-river
```

### Rotate Service Secrets

```bash
# Edit secrets file
sops secrets.yaml

# Update specific secrets
# Save and exit

# Rebuild to apply new secrets
sudo nixos-rebuild switch --flake .#server-river

# Restart affected services
sudo systemctl restart grafana
sudo systemctl restart step-ca
# etc.
```

## 8. Backup and Recovery

### Backup Age Keys

```bash
# Create encrypted backup of age keys
tar -czf age-keys-backup-$(date +%Y%m%d).tar.gz ~/.config/sops/age/
gpg -c age-keys-backup-*.tar.gz
rm age-keys-backup-*.tar.gz

# Store encrypted backup offline
```

### Recovery Procedure

```bash
# Restore age keys from backup
gpg -d age-keys-backup-*.tar.gz.gpg | tar -xzf -

# Copy to system location
sudo cp ~/.config/sops/age/keys.txt /var/lib/sops-nix/key.txt
sudo chmod 600 /var/lib/sops-nix/key.txt

# Rebuild system
sudo nixos-rebuild switch --flake .#server-river
```

## 9. Security Best Practices

### Key Management
- Store age private keys offline
- Use different keys for different environments
- Rotate keys annually or if compromised
- Document key holders and access

### Secret Values
- Use strong, unique passphrases
- Rotate service secrets regularly
- Monitor for secret exposure in logs
- Use principle of least privilege

### Access Control
- Limit who can edit secrets.yaml
- Use git commit signing for secret changes
- Audit secret access regularly
- Monitor for unauthorized decryption

## 10. Troubleshooting

### Cannot Decrypt Secrets

```bash
# Check age key exists
ls -la ~/.config/sops/age/keys.txt
ls -la /var/lib/sops-nix/key.txt

# Verify key permissions
sudo stat /var/lib/sops-nix/key.txt

# Test manual decryption
sops -d secrets.yaml
```

### Service Cannot Access Secrets

```bash
# Check systemd service secret mounts
systemctl status grafana
journalctl -u grafana -f

# Verify secret file creation
ls -la /run/secrets/

# Check sops-nix service
systemctl status sops-nix
```

### Permission Issues

```bash
# Check secret ownership in configuration.nix
# Verify user/group exists
getent passwd grafana
getent group grafana

# Restart sops-nix service
sudo systemctl restart sops-nix
```

## 11. Integration with NixOS

### Automatic Secret Deployment

The sops-nix module automatically:
- Decrypts secrets at boot time
- Sets proper file permissions
- Creates secret files in `/run/secrets/`
- Manages secret lifecycle

### Service Dependencies

Services that depend on secrets should use:
```nix
systemd.services.myservice = {
  after = [ "sops-nix.service" ];
  wants = [ "sops-nix.service" ];
};
```

## 12. Monitoring and Alerting

### Secret Health Checks

```bash
# Add to monitoring scripts
if [ ! -f "/run/secrets/borg-passphrase" ]; then
  echo "CRITICAL: Backup passphrase not available"
fi

# Check secret age (rotation reminder)
find /run/secrets -type f -mtime +90 -ls
```

---

⚠️ **Critical Security Notes:**
- Never commit unencrypted secrets to git
- Store age keys securely offline
- Rotate secrets regularly
- Monitor for unauthorized access
- Test disaster recovery procedures