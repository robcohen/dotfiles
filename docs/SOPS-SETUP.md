# SOPS Secrets Management Setup

This guide walks you through setting up SOPS (Secrets OPerationS) for secure secret management in your NixOS dotfiles.

## Prerequisites

- Age or GPG key for encryption
- SOPS installed (`nix develop` includes it)

## Initial Setup

### 1. Generate Age Key (Recommended)

```bash
# Generate age key
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt

# Show public key (copy this for .sops.yaml)
age-keygen -y ~/.config/sops/age/keys.txt
```

### 2. Configure SOPS

Edit `.sops.yaml` and add your age public key:

```yaml
keys:
  - &user age1your_age_key_here_from_previous_step

creation_rules:
  - path_regex: secrets\.yaml$
    key_groups:
      - age:
          - *user
```

### 3. Create and Edit Secrets

```bash
# Create/edit secrets file
sops secrets.yaml
```

Add your secrets in YAML format:
```yaml
user:
    name: "yourusername"
    email: "your@email.com"
    realName: "Your Real Name"
    githubUsername: "yourghusername"

ssh:
    emergencyKeys:
        - "ssh-ed25519 AAAAC3... your-key-comment"

domains:
    primary: "example.com"
    vpn: "vpn.example.com"
    internal: "internal.example.com"
```

### 4. System Configuration

The secrets are automatically available in your system configurations through:

```nix
config.sops.secrets."user/name".path      # Contains your username
config.sops.secrets."user/email".path     # Contains your email
config.sops.secrets."ssh/emergencyKeys".path  # Contains SSH keys
```

## Key Management

### Backup Your Keys

**Critical**: Backup your age key file. Without it, you cannot decrypt your secrets!

```bash
# Backup to secure location
cp ~/.config/sops/age/keys.txt /path/to/secure/backup/
```

### Rotate Keys

1. Generate new age key
2. Update `.sops.yaml` with new public key
3. Re-encrypt secrets: `sops updatekeys secrets.yaml`
4. Deploy to systems
5. Remove old key from `.sops.yaml`

### Add Team Members

1. Get their age public key
2. Add to `.sops.yaml`:
```yaml
keys:
  - &user1 age1your_key
  - &user2 age1their_key

creation_rules:
  - path_regex: secrets\.yaml$
    key_groups:
      - age:
          - *user1
          - *user2
```
3. Re-encrypt: `sops updatekeys secrets.yaml`

## Security Best Practices

### File Permissions
- Age keys: `chmod 600 ~/.config/sops/age/keys.txt`
- SOPS config: `chmod 644 .sops.yaml`
- Encrypted secrets: `chmod 644 secrets.yaml` (safe since encrypted)

### Key Storage
- Store age keys in secure, backed-up location
- Consider hardware security keys for critical environments
- Never commit unencrypted age keys to git

### Access Control
- Use separate keys for different environments (dev/staging/prod)
- Regularly audit who has access to which secrets
- Rotate keys periodically

## Troubleshooting

### "no keys found" Error
- Verify age key exists: `ls ~/.config/sops/age/keys.txt`
- Check `.sops.yaml` has correct public key
- Ensure SOPS_AGE_KEY_FILE environment variable points to key file

### Decryption Failures
- Verify your public key is in the encrypted file's key list
- Check file permissions on age key
- Try decrypting manually: `sops -d secrets.yaml`

### Build Failures
- Ensure SOPS module is imported in host configurations
- Verify secret paths match what's defined in `modules/sops.nix`
- Check that age key exists on target system at `/var/lib/sops-nix/key.txt`

## Migration from secrets.nix

If you have an existing `secrets.nix` file:

1. Copy values to SOPS format in `secrets.yaml`
2. Test with `sops -d secrets.yaml`
3. Update configurations to use SOPS paths
4. Remove old `secrets.nix` file
5. Deploy and verify

## Advanced Usage

### Environment-Specific Secrets
```yaml
# .sops.yaml
creation_rules:
  - path_regex: secrets/dev\.yaml$
    key_groups:
      - age: [*dev_key]
  - path_regex: secrets/prod\.yaml$
    key_groups:
      - age: [*prod_key]
```

### Templating
Use SOPS templates for complex configurations:
```nix
sops.templates."config.json".content = ''
  {
    "api_key": "${config.sops.placeholder."api/key"}",
    "database_url": "${config.sops.placeholder."db/url"}"
  }
'';
```

For more advanced features, see the [sops-nix documentation](https://github.com/Mic92/sops-nix).