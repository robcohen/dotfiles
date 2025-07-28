#!/usr/bin/env bash
# SOPS key rotation script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGE_DIR="$HOME/.config/sops/age"
AGE_KEY_FILE="$AGE_DIR/keys.txt"
AGE_KEY_BACKUP="$AGE_DIR/keys.backup.$(date +%Y%m%d_%H%M%S).txt"
SOPS_CONFIG="$REPO_ROOT/.sops.yaml"

echo "🔄 SOPS Key Rotation"
echo "===================="

# Verify current setup
if [[ ! -f "$AGE_KEY_FILE" ]]; then
    echo "❌ No existing age key found at $AGE_KEY_FILE"
    echo "   Run sops-init.sh first"
    exit 1
fi

if [[ ! -f "$SOPS_CONFIG" ]]; then
    echo "❌ No .sops.yaml configuration found"
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

# Backup current key
echo "💾 Backing up current key..."
cp "$AGE_KEY_FILE" "$AGE_KEY_BACKUP"
echo "✓ Backup saved to: $AGE_KEY_BACKUP"

# Generate new key
echo "🔑 Generating new age key..."
age-keygen -o "$AGE_KEY_FILE"
chmod 600 "$AGE_KEY_FILE"

NEW_KEY=$(age-keygen -y "$AGE_KEY_FILE")
echo "✓ Generated new key: $NEW_KEY"

# Update .sops.yaml
echo "📝 Updating .sops.yaml..."
sed -i "s/$CURRENT_KEY/$NEW_KEY/g" "$SOPS_CONFIG"
echo "✓ Updated configuration"

# Re-encrypt all secrets files
echo "🔐 Re-encrypting secrets files..."

for secrets_file in "$REPO_ROOT"/secrets*.yaml "$REPO_ROOT"/secrets/*.yaml; do
    if [[ -f "$secrets_file" ]] && grep -q "sops:" "$secrets_file"; then
        echo "  • Re-encrypting $(basename "$secrets_file")..."

        # Test if we can decrypt with old key first
        if SOPS_AGE_KEY_FILE="$AGE_KEY_BACKUP" sops -d "$secrets_file" > /dev/null 2>&1; then
            # Decrypt with old key and re-encrypt with new key
            SOPS_AGE_KEY_FILE="$AGE_KEY_BACKUP" sops -d "$secrets_file" | sops -e /dev/stdin > "$secrets_file.tmp"
            mv "$secrets_file.tmp" "$secrets_file"
            echo "    ✓ Re-encrypted successfully"
        else
            echo "    ⚠️  Could not decrypt $secrets_file with old key - skipping"
        fi
    fi
done

# Verify new key works
echo "🔍 Verifying new key..."
if sops -d "$REPO_ROOT/secrets.yaml" > /dev/null 2>&1; then
    echo "✓ New key verification successful"
else
    echo "❌ New key verification failed!"
    echo "   Restoring backup key..."
    cp "$AGE_KEY_BACKUP" "$AGE_KEY_FILE"
    sed -i "s/$NEW_KEY/$CURRENT_KEY/g" "$SOPS_CONFIG"
    echo "   Backup restored. Please check your setup."
    exit 1
fi

echo ""
echo "🎉 Key rotation complete!"
echo ""
echo "📋 Old key (backed up): $CURRENT_KEY"
echo "📋 New key (active):     $NEW_KEY"
echo "💾 Backup location:      $AGE_KEY_BACKUP"
echo ""
echo "⚠️  Important next steps:"
echo "1. Test that you can still decrypt secrets: sops -d secrets.yaml"
echo "2. Deploy to all systems: sudo nixos-rebuild switch --flake ."
echo "3. Verify all systems can decrypt secrets"
echo "4. Only then delete the backup key: rm $AGE_KEY_BACKUP"
echo ""
echo "🔒 Keep the backup key until you've verified everything works!"
