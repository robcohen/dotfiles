#!/usr/bin/env bash
# SOPS initialization script for new machines
#
# This script sets up SOPS secrets management with age encryption.
#
# Key locations (standard sops paths):
#   Age key:     ~/.config/sops/age/keys.txt
#   Secrets:     ~/.secrets/secrets.yaml
#
# For existing users with keys in high-trust-repos, create symlinks:
#   ln -s ~/Documents/high-trust-repos/my-secrets/age-keys/$HOST/keys.txt ~/.config/sops/age/keys.txt
#   ln -s ~/Documents/high-trust-repos/my-secrets/sops/secrets.yaml ~/.secrets/secrets.yaml

set -euo pipefail

AGE_DIR="$HOME/.config/sops/age"
AGE_KEY_FILE="$AGE_DIR/keys.txt"
SECRETS_DIR="$HOME/.secrets"
SECRETS_FILE="$SECRETS_DIR/secrets.yaml"

echo "🔐 SOPS Secrets Management Setup"
echo "================================"

# Check if age key already exists (file or symlink)
if [[ -e "$AGE_KEY_FILE" ]]; then
    echo "✓ Age key exists at $AGE_KEY_FILE"
    if [[ -L "$AGE_KEY_FILE" ]]; then
        echo "  (symlink to $(readlink "$AGE_KEY_FILE"))"
    fi
    AGE_PUBLIC_KEY=$(age-keygen -y "$AGE_KEY_FILE" 2>/dev/null)
    echo "✓ Public key: $AGE_PUBLIC_KEY"
else
    echo "📁 Creating age key directory..."
    mkdir -p "$AGE_DIR"

    echo "🔑 Generating new age key..."
    age-keygen -o "$AGE_KEY_FILE"

    echo "🔒 Setting secure permissions..."
    chmod 600 "$AGE_KEY_FILE"

    AGE_PUBLIC_KEY=$(age-keygen -y "$AGE_KEY_FILE")
    echo "✓ Generated new age key with public key: $AGE_PUBLIC_KEY"
    echo ""
    echo "⚠️  Important: Add this public key to .sops.yaml in your dotfiles repo"
fi

# Check secrets file
if [[ -e "$SECRETS_FILE" ]]; then
    echo "✓ Secrets file exists at $SECRETS_FILE"
    if [[ -L "$SECRETS_FILE" ]]; then
        echo "  (symlink to $(readlink "$SECRETS_FILE"))"
    fi

    # Test decryption
    if sops -d "$SECRETS_FILE" > /dev/null 2>&1; then
        echo "✓ Successfully verified decryption access"
    else
        echo "❌ Cannot decrypt secrets file"
        echo "   Your key may not be authorized. Check .sops.yaml has your public key."
    fi
else
    echo "📁 Creating secrets directory..."
    mkdir -p "$SECRETS_DIR"
    chmod 700 "$SECRETS_DIR"

    echo "📝 Creating new secrets template..."
    cat > "$SECRETS_FILE" << EOF
# SOPS encrypted secrets file
# Edit with: sops ~/.secrets/secrets.yaml

# User configuration
user:
    name: "$(whoami)"
    email: "user@example.com"
    realName: "Your Real Name"
    githubUsername: "yourghusername"
    hashedPassword: ""

# Domain configuration
domains:
    primary: "example.com"
    vpn: "vpn.example.com"
    internal: "internal.example.com"

# Service URLs (private infrastructure)
services:
    ollama:
        baseURL: "http://localhost:11434"
EOF

    echo "🔐 Encrypting secrets file..."
    if sops -e -i "$SECRETS_FILE"; then
        chmod 600 "$SECRETS_FILE"
        echo "✓ Created encrypted secrets.yaml"
    else
        echo "❌ Failed to encrypt. Check .sops.yaml has a creation rule for ~/.secrets/"
        rm -f "$SECRETS_FILE"
        exit 1
    fi
fi

echo ""
echo "🎉 SOPS setup complete!"
echo ""
echo "Key locations:"
echo "  Age key:  $AGE_KEY_FILE"
echo "  Secrets:  $SECRETS_FILE"
echo ""
echo "Next steps:"
echo "1. Edit secrets: sops ~/.secrets/secrets.yaml"
echo "2. Rebuild system: sudo nixos-rebuild switch --flake ~/Documents/dotfiles"
echo "3. Rebuild home:   home-manager switch --flake ~/Documents/dotfiles"
echo ""
echo "🔑 Your age public key: $AGE_PUBLIC_KEY"
