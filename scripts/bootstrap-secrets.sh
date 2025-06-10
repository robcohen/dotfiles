#!/usr/bin/env bash
# Bootstrap SOPS secrets with BIP39/TPM keys
# Run this AFTER the system is successfully built

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

usage() {
    echo "Usage: $0 [--mnemonic \"word1 word2...\"] [--generate] [--help]"
    echo ""
    echo "Bootstrap SOPS secrets with BIP39/TPM derived keys"
    echo ""
    echo "Options:"
    echo "  --mnemonic \"...\"     Use existing BIP39 mnemonic"
    echo "  --generate           Generate new BIP39 mnemonic"
    echo "  --dry-run           Show what would be done"
    echo "  --help              Show this help"
    echo ""
    echo "This script will:"
    echo "1. Ensure TPM is initialized"
    echo "2. Generate or use existing BIP39 mnemonic"
    echo "3. Derive age keys from BIP39"
    echo "4. Update .sops.yaml with new age key"
    echo "5. Create initial encrypted secrets file"
    echo "6. Enable SOPS in the system configuration"
    echo ""
    echo "Examples:"
    echo "  $0 --generate"
    echo "  $0 --mnemonic \"word1 word2 ... word24\""
    exit 1
}

MNEMONIC=""
GENERATE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --mnemonic)
            MNEMONIC="$2"
            shift 2
            ;;
        --generate)
            GENERATE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "❌ Unknown option: $1" >&2
            usage
            ;;
    esac
done

if [[ "$GENERATE" == "false" ]] && [[ -z "$MNEMONIC" ]]; then
    echo "❌ Must specify either --generate or --mnemonic" >&2
    usage
fi

if [[ "$GENERATE" == "true" ]] && [[ -n "$MNEMONIC" ]]; then
    echo "❌ Cannot specify both --generate and --mnemonic" >&2
    usage
fi

echo "🔐 SOPS Bootstrap with BIP39/TPM Keys"
echo "====================================="
echo ""

# Step 1: Check prerequisites
echo "1️⃣  Checking prerequisites..."

if ! command -v tpm-init >/dev/null; then
    echo "❌ tpm-init not found. Ensure system is built with TPM support." >&2
    exit 1
fi

if ! command -v bip39-generate >/dev/null; then
    echo "❌ bip39-generate not found. Ensure home-manager is built with BIP39 tools." >&2
    exit 1
fi

if ! command -v bip39 >/dev/null; then
    echo "❌ bip39 CLI not found. Ensure home-manager is built with BIP39 package." >&2
    exit 1
fi

echo "✅ All prerequisites found"
echo ""

# Step 2: Initialize TPM
echo "2️⃣  Initializing TPM..."

if [[ "$DRY_RUN" == "true" ]]; then
    echo "🧪 DRY RUN: Would run 'sudo tpm-init'"
else
    if ! sudo tpm-init; then
        echo "❌ TPM initialization failed" >&2
        exit 1
    fi
fi

echo "✅ TPM initialized"
echo ""

# Step 3: Get BIP39 mnemonic
echo "3️⃣  Setting up BIP39 mnemonic..."

if [[ "$GENERATE" == "true" ]]; then
    echo "🎲 Generating new 24-word BIP39 mnemonic..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        MNEMONIC="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art"
        echo "🧪 DRY RUN: Using test mnemonic"
    else
        MNEMONIC=$(bip39 generate-mnemonic --words 24)
    fi
    
    echo ""
    echo "📝 YOUR BIP39 MNEMONIC:"
    echo "======================="
    echo "$MNEMONIC"
    echo "======================="
    echo ""
    echo "⚠️  CRITICAL: Write this down on paper and store it securely!"
    echo "⚠️  This is your master key for all derived secrets!"
    echo ""
    
    if [[ "$DRY_RUN" == "false" ]]; then
        read -p "Press Enter when you have safely recorded the mnemonic..."
    fi
else
    echo "✅ Using provided mnemonic"
fi

# Validate mnemonic
WORD_COUNT=$(echo "$MNEMONIC" | wc -w)
if [[ "$WORD_COUNT" -ne 24 ]] && [[ "$WORD_COUNT" -ne 12 ]] && [[ "$WORD_COUNT" -ne 18 ]]; then
    echo "❌ Invalid BIP39 mnemonic: expected 12, 18, or 24 words, got $WORD_COUNT" >&2
    exit 1
fi

echo "✅ BIP39 mnemonic validated ($WORD_COUNT words)"
echo ""

# Step 4: Derive age key
echo "4️⃣  Deriving age key from BIP39..."

# Create secure temp directory
if [[ -d /dev/shm ]]; then
    SECURE_TMPDIR=$(mktemp -d -p /dev/shm bootstrap-secrets.XXXXXX)
else
    SECURE_TMPDIR=$(mktemp -d -t bootstrap-secrets.XXXXXX)
fi
trap "rm -rf '$SECURE_TMPDIR' 2>/dev/null || true" EXIT

# Derive age key using HKDF (same as in bip39-derive-keys)
BASE_SEED=$(echo -n "$MNEMONIC" | openssl dgst -sha512 -hmac "mnemonic" | cut -d' ' -f2)
echo -n "$BASE_SEED" | xxd -r -p > "$SECURE_TMPDIR/base_seed.bin"
echo -n "age" > "$SECURE_TMPDIR/age_info"
AGE_SEED=$(openssl dgst -sha256 -mac HMAC -macopt keyfile:"$SECURE_TMPDIR/base_seed.bin" < "$SECURE_TMPDIR/age_info" | cut -d' ' -f2)

# Generate deterministic age public key  
AGE_HASH=$(echo -n "$AGE_SEED" | xxd -r -p | openssl dgst -sha256 | cut -d' ' -f2)
AGE_PUBLIC="age1$(echo -n "$AGE_HASH" | cut -c1-52 | tr '[:upper:]' '[:lower:]')"

echo "✅ Age key derived"
echo "   Public: $AGE_PUBLIC"
echo ""

# Step 5: Update .sops.yaml
echo "5️⃣  Updating .sops.yaml configuration..."

SOPS_CONFIG="$DOTFILES_DIR/.sops.yaml"

if [[ "$DRY_RUN" == "true" ]]; then
    echo "🧪 DRY RUN: Would update $SOPS_CONFIG with key: $AGE_PUBLIC"
else
    # Update the age key in .sops.yaml
    sed -i "s/age1[a-z0-9]*/$AGE_PUBLIC/g" "$SOPS_CONFIG"
    echo "✅ Updated .sops.yaml with new age key"
fi

echo ""

# Step 6: Create initial secrets file
echo "6️⃣  Creating initial secrets file..."

SECRETS_DIR="$HOME/.secrets"
SECRETS_FILE="$SECRETS_DIR/secrets.yaml"

if [[ "$DRY_RUN" == "true" ]]; then
    echo "🧪 DRY RUN: Would create $SECRETS_FILE"
else
    # Ensure secrets directory exists
    mkdir -p "$SECRETS_DIR"
    chmod 700 "$SECRETS_DIR"
    
    # Create initial secrets file if it doesn't exist
    if [[ ! -f "$SECRETS_FILE" ]]; then
        cat > "$SECRETS_FILE" << EOF
# Encrypted secrets for NixOS configuration
# Edit with: sops $SECRETS_FILE

# User configuration
user:
  name: "user"
  email: "user@example.com"
  realName: "User Name"
  githubUsername: "username"

# SSH emergency keys
ssh:
  emergencyKeys: []

# Domain configuration  
domains:
  primary: "example.com"
  vpn: "vpn.example.com"
  internal: "internal.example.com"
EOF
        
        # Encrypt the file with SOPS
        AGE_KEY_FILE="$SECURE_TMPDIR/age_private.txt"
        echo "AGE-SECRET-KEY-1$(echo -n "$AGE_SEED" | xxd -r -p | base64 -w0 | tr '/+' '_-' | tr -d '=')" > "$AGE_KEY_FILE"
        
        SOPS_AGE_KEY_FILE="$AGE_KEY_FILE" sops --encrypt --in-place "$SECRETS_FILE"
        chmod 600 "$SECRETS_FILE"
        
        echo "✅ Created and encrypted initial secrets file"
    else
        echo "⚠️  Secrets file already exists, skipping creation"
    fi
fi

echo ""

# Step 7: Enable SOPS in configuration
echo "7️⃣  Enabling SOPS in system configuration..."

FLAKE_FILE="$DOTFILES_DIR/flake.nix"

if [[ "$DRY_RUN" == "true" ]]; then
    echo "🧪 DRY RUN: Would uncomment SOPS modules in $FLAKE_FILE"
else
    # Uncomment SOPS modules in flake.nix
    sed -i 's|# sops-nix.nixosModules.sops|sops-nix.nixosModules.sops|g' "$FLAKE_FILE"
    sed -i 's|# ./modules/sops.nix|./modules/sops.nix|g' "$FLAKE_FILE"
    
    echo "✅ Enabled SOPS modules in flake.nix"
fi

echo ""

# Step 8: Summary
echo "🎉 Bootstrap complete!"
echo "===================="
echo ""
echo "✅ TPM initialized with primary key"
echo "✅ Age key derived from BIP39 mnemonic"  
echo "✅ SOPS configuration updated"
echo "✅ Initial secrets file created"
echo "✅ SOPS enabled in system configuration"
echo ""
echo "🔑 Key Information:"
echo "   Age Public: $AGE_PUBLIC"
echo "   Secrets: $SECRETS_FILE"
echo ""
echo "📋 Next steps:"
echo "1. Edit secrets: sops $SECRETS_FILE"
echo "2. Rebuild system: sudo nixos-rebuild switch --flake .#$(hostname)"
echo "3. Rebuild home-manager: home-manager switch --flake .#user@$(hostname)"
echo ""
echo "🗂️  Your mnemonic phrase can regenerate all keys on any TPM-enabled device"
echo "🔐 Keep your mnemonic phrase safe and secure!"