#!/usr/bin/env bash
# Bootstrap SOPS secrets with BIP39/TPM keys
# Run this AFTER the system is successfully built

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

usage() {
    echo "Usage: $0 --mnemonic \"word1 word2...\" [--dry-run] [--help]"
    echo ""
    echo "Bootstrap SOPS secrets with BIP39/TPM derived keys"
    echo ""
    echo "Required:"
    echo "  --mnemonic \"...\"     BIP39 mnemonic phrase (12, 18, or 24 words)"
    echo ""
    echo "Options:"
    echo "  --dry-run           Show what would be done"
    echo "  --help              Show this help"
    echo ""
    echo "This script will:"
    echo "1. Ensure TPM is initialized"
    echo "2. Derive age keys from BIP39 mnemonic using unified keys system"
    echo "3. Update .sops.yaml with new age key"
    echo "4. Create initial encrypted secrets file"
    echo "5. Enable SOPS in the system configuration"
    echo ""
    echo "Generate a mnemonic first:"
    echo "  bip39 generate --words 24 --quiet"
    echo ""
    echo "Then use this script:"
    echo "  $0 --mnemonic \"word1 word2 ... word24\""
    exit 1
}

MNEMONIC=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --mnemonic)
            MNEMONIC="$2"
            shift 2
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

if [[ -z "$MNEMONIC" ]]; then
    echo "❌ Missing required --mnemonic argument" >&2
    echo ""
    echo "Generate a mnemonic first:"
    echo "  bip39 generate --words 24 --quiet"
    echo ""
    usage
fi

echo "🔐 SOPS Bootstrap with BIP39/TPM Keys"
echo "====================================="
echo ""

# Step 1: Check prerequisites
echo "1️⃣  Checking prerequisites..."

if ! command -v tpm-init >/dev/null && [[ ! -x /etc/scripts/tpm-init ]]; then
    echo "❌ tpm-init not found. Ensure system is built with TPM support." >&2
    exit 1
fi

# Use system scripts directly if not in PATH
if [[ -x /etc/scripts/tpm-init ]]; then
    TPM_INIT_CMD="/etc/scripts/tpm-init"
else
    TPM_INIT_CMD="tpm-init"
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
    echo "🧪 DRY RUN: Would run 'sudo $TPM_INIT_CMD'"
else
    if ! sudo "$TPM_INIT_CMD"; then
        echo "❌ TPM initialization failed" >&2
        exit 1
    fi
fi

echo "✅ TPM initialized"
echo ""

# Step 3: Validate BIP39 mnemonic
echo "3️⃣  Validating BIP39 mnemonic..."

# Validate mnemonic
WORD_COUNT=$(echo "$MNEMONIC" | wc -w)
if [[ "$WORD_COUNT" -ne 24 ]] && [[ "$WORD_COUNT" -ne 12 ]] && [[ "$WORD_COUNT" -ne 18 ]]; then
    echo "❌ Invalid BIP39 mnemonic: expected 12, 18, or 24 words, got $WORD_COUNT" >&2
    echo ""
    echo "Generate a valid mnemonic with:"
    echo "  bip39 generate --words 24 --quiet"
    exit 1
fi

echo "✅ BIP39 mnemonic validated ($WORD_COUNT words)"
echo ""

# Step 4: Derive keys using BIP39 unified keys system
echo "4️⃣  Deriving keys using BIP39 unified system..."

if [[ "$DRY_RUN" == "true" ]]; then
    echo "🧪 DRY RUN: Would run 'bip39-unified-keys --mnemonic \"<provided mnemonic>\" --setup-sops'"
    AGE_PUBLIC="age1dryrun123456789abcdefghijklmnopqrstuvwxyz1234567890ab"
else
    # Use the BIP39 unified keys system to derive deterministic age key
    # This creates TPM-sealed age keys and configures SOPS
    if ! bip39-unified-keys --mnemonic "$MNEMONIC" --setup-sops 2>&1; then
        echo "❌ BIP39 unified keys derivation failed" >&2
        exit 1
    fi

    # Extract the age public key from .sops.yaml
    AGE_PUBLIC=$(grep -o 'age1[a-z0-9]*' "$DOTFILES_DIR/.sops.yaml" | head -1)
fi

echo "✅ BIP39 unified keys system completed"
echo "   Age public key: $AGE_PUBLIC"
echo ""

# Step 5: SOPS configuration (already handled by unified keys system)
echo "5️⃣  SOPS configuration..."
echo "✅ .sops.yaml already updated by BIP39 unified keys system"
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

# Domain configuration
domains:
  primary: "example.com"
  vpn: "vpn.example.com"
  internal: "internal.example.com"
EOF

        # Encrypt the file with SOPS using the TPM-sealed age key
        # The unified keys system handles age key access automatically
        sops --encrypt --in-place "$SECRETS_FILE"
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
echo "   - Update user information with your actual details"
echo "   - Replace example.com domains with your actual domains"
echo "2. Rebuild system: sudo nixos-rebuild switch --flake .#$(hostname)"
echo "3. Rebuild home-manager: home-manager switch --flake .#user@$(hostname)"
echo ""
echo "🗂️  Your BIP39 mnemonic can regenerate all keys on any TPM-enabled device"
echo "🔐 Keep your mnemonic phrase safe and secure!"
echo ""
echo "💡 To generate a new mnemonic in the future:"
echo "   bip39 generate --words 24 --quiet"
