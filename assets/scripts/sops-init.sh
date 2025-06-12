#!/usr/bin/env bash
# SOPS initialization script for new users

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGE_DIR="$HOME/.config/sops/age"
AGE_KEY_FILE="$AGE_DIR/keys.txt"
SOPS_CONFIG="$REPO_ROOT/.sops.yaml"
SECRETS_FILE="$REPO_ROOT/secrets.yaml"

echo "🔐 SOPS Secrets Management Setup"
echo "================================"

# Check if age key already exists
if [[ -f "$AGE_KEY_FILE" ]]; then
    echo "✓ Age key already exists at $AGE_KEY_FILE"
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
fi

# Update .sops.yaml with the age key
echo "📝 Updating .sops.yaml configuration..."
cat > "$SOPS_CONFIG" << EOF
keys:
  - &user $AGE_PUBLIC_KEY

creation_rules:
  - path_regex: secrets\.yaml$
    key_groups:
      - age:
          - *user
  
  # Separate rules for different environments
  - path_regex: secrets/.*\.yaml$
    key_groups:
      - age:
          - *user
EOF

echo "✓ Updated $SOPS_CONFIG"

# Check if secrets.yaml exists and is encrypted
if [[ -f "$SECRETS_FILE" ]]; then
    if grep -q "sops:" "$SECRETS_FILE" && grep -q "ENC\[" "$SECRETS_FILE"; then
        echo "✓ Encrypted secrets file already exists"
        
        # Test decryption
        if sops -d "$SECRETS_FILE" > /dev/null 2>&1; then
            echo "✓ Successfully verified decryption access"
        else
            echo "❌ Cannot decrypt existing secrets file"
            echo "   This might mean your key is not authorized for this file"
            echo "   You may need to re-encrypt with: sops updatekeys secrets.yaml"
        fi
    else
        echo "⚠️  Unencrypted secrets.yaml found - this needs to be encrypted!"
        echo "   Run: sops -e -i secrets.yaml"
    fi
else
    echo "📝 Creating new secrets template..."
    cat > "$SECRETS_FILE" << EOF
# SOPS encrypted secrets file
# Edit with: sops secrets.yaml

user:
    name: "$(whoami)"
    email: "user@example.com"
    realName: "Your Real Name"
    githubUsername: "yourghusername"

domains:
    primary: "example.com"
    vpn: "vpn.example.com"
    internal: "internal.example.com"

sops:
    kms: []
    gcp_kms: []
    azure_kv: []
    hc_vault: []
    age:
        - recipient: $AGE_PUBLIC_KEY
          enc: |
            -----BEGIN AGE ENCRYPTED FILE-----
            # This will be filled when you encrypt the file
            -----END AGE ENCRYPTED FILE-----
    lastmodified: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    mac: ENC[AES256_GCM,data:placeholder,iv:placeholder,tag:placeholder,type:str]
    pgp: []
    version: 3.9.0
EOF
    
    echo "🔐 Encrypting secrets file..."
    sops -e -i "$SECRETS_FILE"
    echo "✓ Created encrypted secrets.yaml"
fi

echo ""
echo "🎉 SOPS setup complete!"
echo ""
echo "Next steps:"
echo "1. Edit secrets: sops secrets.yaml"
echo "2. Update your personal information in the secrets file"
echo "3. Rebuild your system: sudo nixos-rebuild switch --flake ."
echo ""
echo "📚 For more information, see: docs/SOPS-SETUP.md"
echo ""
echo "🔑 Your age public key: $AGE_PUBLIC_KEY"
echo "💾 Backup your private key: $AGE_KEY_FILE"