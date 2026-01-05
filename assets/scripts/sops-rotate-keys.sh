#!/usr/bin/env bash
# SOPS key rotation script
#
# Rotates the user's age key and re-encrypts all secrets.
#
# Key locations:
#   Age key:  ~/.config/sops/age/keys.txt
#   Secrets:  ~/.secrets/secrets.yaml

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGE_DIR="$HOME/.config/sops/age"
AGE_KEY_FILE="$AGE_DIR/keys.txt"
AGE_KEY_BACKUP="$AGE_DIR/keys.backup.$(date +%Y%m%d_%H%M%S).txt"
SECRETS_FILE="$HOME/.secrets/secrets.yaml"
SOPS_CONFIG="$REPO_ROOT/.sops.yaml"

echo "🔄 SOPS Key Rotation"
echo "===================="

# Check for symlinks - warn that rotation may not work as expected
if [[ -L "$AGE_KEY_FILE" ]]; then
    echo "⚠️  Age key is a symlink to: $(readlink "$AGE_KEY_FILE")"
    echo "   Key rotation will modify the target file."
    echo ""
fi

if [[ -L "$SECRETS_FILE" ]]; then
    echo "⚠️  Secrets file is a symlink to: $(readlink "$SECRETS_FILE")"
    echo "   Re-encryption will modify the target file."
    echo ""
fi

# Verify current setup
if [[ ! -e "$AGE_KEY_FILE" ]]; then
    echo "❌ No existing age key found at $AGE_KEY_FILE"
    echo "   Run sops-init.sh first"
    exit 1
fi

if [[ ! -f "$SOPS_CONFIG" ]]; then
    echo "❌ No .sops.yaml configuration found at $SOPS_CONFIG"
    exit 1
fi

if [[ ! -e "$SECRETS_FILE" ]]; then
    echo "❌ No secrets file found at $SECRETS_FILE"
    exit 1
fi

# Show current key
CURRENT_KEY=$(age-keygen -y "$AGE_KEY_FILE")
echo "📋 Current public key: $CURRENT_KEY"

# Confirm rotation
echo ""
read -p "⚠️  Are you sure you want to rotate your age key? This cannot be undone. [y/N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "🚫 Key rotation cancelled"
    exit 0
fi

# Resolve symlink for backup (backup the actual file)
ACTUAL_KEY_FILE="$AGE_KEY_FILE"
if [[ -L "$AGE_KEY_FILE" ]]; then
    ACTUAL_KEY_FILE="$(readlink -f "$AGE_KEY_FILE")"
    AGE_KEY_BACKUP="$(dirname "$ACTUAL_KEY_FILE")/keys.backup.$(date +%Y%m%d_%H%M%S).txt"
fi

# Backup current key
echo "💾 Backing up current key..."
cp "$ACTUAL_KEY_FILE" "$AGE_KEY_BACKUP"
echo "✓ Backup saved to: $AGE_KEY_BACKUP"

# Generate new key
echo "🔑 Generating new age key..."
age-keygen -o "$ACTUAL_KEY_FILE"
chmod 600 "$ACTUAL_KEY_FILE"

NEW_KEY=$(age-keygen -y "$AGE_KEY_FILE")
echo "✓ Generated new key: $NEW_KEY"

# Update .sops.yaml
echo "📝 Updating .sops.yaml..."
sed -i "s/$CURRENT_KEY/$NEW_KEY/g" "$SOPS_CONFIG"
echo "✓ Updated configuration"

# Re-encrypt secrets file
echo "🔐 Re-encrypting secrets file..."
ACTUAL_SECRETS_FILE="$SECRETS_FILE"
if [[ -L "$SECRETS_FILE" ]]; then
    ACTUAL_SECRETS_FILE="$(readlink -f "$SECRETS_FILE")"
fi

if SOPS_AGE_KEY_FILE="$AGE_KEY_BACKUP" sops -d "$ACTUAL_SECRETS_FILE" > /dev/null 2>&1; then
    # Decrypt with old key and re-encrypt with new key
    SOPS_AGE_KEY_FILE="$AGE_KEY_BACKUP" sops -d "$ACTUAL_SECRETS_FILE" | sops -e /dev/stdin > "$ACTUAL_SECRETS_FILE.tmp"
    mv "$ACTUAL_SECRETS_FILE.tmp" "$ACTUAL_SECRETS_FILE"
    echo "✓ Re-encrypted $SECRETS_FILE"
else
    echo "❌ Could not decrypt secrets with old key"
    echo "   Restoring backup key..."
    cp "$AGE_KEY_BACKUP" "$ACTUAL_KEY_FILE"
    sed -i "s/$NEW_KEY/$CURRENT_KEY/g" "$SOPS_CONFIG"
    exit 1
fi

# Verify new key works
echo "🔍 Verifying new key..."
if sops -d "$SECRETS_FILE" > /dev/null 2>&1; then
    echo "✓ New key verification successful"
else
    echo "❌ New key verification failed!"
    echo "   Restoring backup key..."
    cp "$AGE_KEY_BACKUP" "$ACTUAL_KEY_FILE"
    sed -i "s/$NEW_KEY/$CURRENT_KEY/g" "$SOPS_CONFIG"
    echo "   Backup restored. Please check your setup."
    exit 1
fi

echo ""
echo "🎉 Key rotation complete!"
echo ""
echo "📋 Old key (backed up): $CURRENT_KEY"
echo "📋 New key (active):    $NEW_KEY"
echo "💾 Backup location:     $AGE_KEY_BACKUP"
echo ""
echo "⚠️  Important next steps:"
echo "1. Test decryption: sops -d ~/.secrets/secrets.yaml"
echo "2. Commit .sops.yaml changes: git add .sops.yaml && git commit -m 'Rotate age key'"
echo "3. Deploy to all systems: sudo nixos-rebuild switch && home-manager switch"
echo "4. Verify all systems can decrypt secrets"
echo "5. Only then delete the backup key: rm $AGE_KEY_BACKUP"
echo ""
echo "🔒 Keep the backup key until you've verified everything works!"
