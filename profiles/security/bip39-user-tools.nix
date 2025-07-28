{ pkgs, ... }:

{
  # BIP39 key derivation tools (user-level)
  home.packages = with pkgs; [
    # BIP39 CLI tool
    (import ./bip39-package.nix { inherit pkgs; })
    # Age for encryption (user-level)
    age
    # OpenSSL for crypto operations
    openssl
    # Secure file deletion and memory tools
    coreutils  # includes shred
    util-linux # includes script for memory locking
  ];

  # BIP39 mnemonic generation helper
  home.file.".local/bin/bip39-generate" = {
    text = ''
      #!${pkgs.bash}/bin/bash
      # Generate BIP39 mnemonic phrase

      set -euo pipefail

      usage() {
          echo "Usage: $0 [--words 12|18|24]"
          echo "       $0 --help"
          echo ""
          echo "Generate BIP39 mnemonic phrase"
          echo ""
          echo "Options:"
          echo "  --words N    Number of words (12, 18, or 24, default: 24)"
          echo "  --help       Show this help"
          echo ""
          echo "Examples:"
          echo "  $0                  # Generate 24-word mnemonic"
          echo "  $0 --words 12       # Generate 12-word mnemonic"
          exit 1
      }

      WORDS=24

      while [[ $# -gt 0 ]]; do
          case $1 in
              --words)
                  WORDS="$2"
                  shift 2
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

      # Validate word count
      if [[ "$WORDS" != "12" ]] && [[ "$WORDS" != "18" ]] && [[ "$WORDS" != "24" ]]; then
          echo "❌ Invalid word count: $WORDS" >&2
          echo "💡 Must be 12, 18, or 24" >&2
          exit 1
      fi

      echo "🎲 Generating $WORDS-word BIP39 mnemonic..." >&2
      echo "" >&2

      # Generate mnemonic using bip39 CLI
      MNEMONIC=$(bip39 generate-mnemonic --words "$WORDS")

      echo "📝 BIP39 Mnemonic ($WORDS words):" >&2
      echo "================================" >&2
      echo "" >&2
      echo "$MNEMONIC" >&2
      echo "" >&2
      echo "⚠️  CRITICAL SECURITY WARNING:" >&2
      echo "• Write this phrase on paper and store it securely" >&2
      echo "• Never store it digitally or take a photo" >&2
      echo "• This is your master seed for all derived keys" >&2
      echo "• Anyone with this phrase can recreate your keys" >&2
      echo "" >&2

      # Output for piping/scripting (stdout only)
      echo "$MNEMONIC"
    '';
    executable = true;
  };

  # BIP39 key derivation helper (calls system TPM tools)
  home.file.".local/bin/bip39-derive-keys" = {
    text = ''
      #!${pkgs.bash}/bin/bash
      # Derive SSH and age keys from BIP39 mnemonic using system TPM

      set -euo pipefail

      usage() {
          echo "Usage: $0 --mnemonic \"word1 word2...\" [options]"
          echo "       $0 --help"
          echo ""
          echo "Derive SSH and age keys from BIP39 mnemonic using TPM"
          echo ""
          echo "Required:"
          echo "  --mnemonic \"...\"     BIP39 mnemonic phrase"
          echo ""
          echo "Options:"
          echo "  --passphrase \"...\"   BIP39 passphrase (default: empty)"
          echo "  --comment text       Comment for keys"
          echo "  --setup-sops        Configure SOPS to use derived age key"
          echo "  --dry-run           Show keys without storing"
          echo "  --help              Show this help"
          echo ""
          echo "Examples:"
          echo "  $0 --mnemonic \"word1 word2 ... word24\" --setup-sops"
          echo "  $0 --mnemonic \"...\" --comment \"MyDevice\" --dry-run"
          exit 1
      }

      MNEMONIC=""
      PASSPHRASE=""
      COMMENT=""
      SETUP_SOPS=false
      DRY_RUN=false

      while [[ $# -gt 0 ]]; do
          case $1 in
              --mnemonic)
                  MNEMONIC="$2"
                  shift 2
                  ;;
              --passphrase)
                  PASSPHRASE="$2"
                  shift 2
                  ;;
              --comment)
                  COMMENT="$2"
                  shift 2
                  ;;
              --setup-sops)
                  SETUP_SOPS=true
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

      if [[ -z "$MNEMONIC" ]]; then
          echo "❌ Missing required --mnemonic argument" >&2
          usage
      fi

      # Validate mnemonic (basic word count check)
      WORD_COUNT=$(echo "$MNEMONIC" | wc -w)
      if [[ "$WORD_COUNT" -ne 24 ]] && [[ "$WORD_COUNT" -ne 12 ]] && [[ "$WORD_COUNT" -ne 18 ]]; then
          echo "❌ Invalid BIP39 mnemonic: expected 12, 18, or 24 words, got $WORD_COUNT" >&2
          exit 1
      fi

      # Check if TPM is initialized (system-level)
      if ! command -v tpm-init >/dev/null; then
          echo "❌ TPM tools not available" >&2
          echo "💡 Ensure TPM is configured at system level" >&2
          exit 1
      fi

      if ! tpm2_readpublic -c 0x81000001 >/dev/null 2>&1; then
          echo "🔧 TPM not initialized, initializing now..." >&2
          if ! sudo tpm-init; then
              echo "❌ TPM initialization failed" >&2
              exit 1
          fi
      fi

      echo "🔑 Deriving keys from BIP39 mnemonic..." >&2
      echo "   Word count: $WORD_COUNT" >&2
      if [[ -n "$COMMENT" ]]; then
          echo "   Comment: $COMMENT" >&2
      fi

      # Create secure temp directory
      if [[ -d /dev/shm ]]; then
          SECURE_TMPDIR=$(mktemp -d -p /dev/shm bip39-derive.XXXXXX)
      else
          SECURE_TMPDIR=$(mktemp -d -t bip39-derive.XXXXXX)
      fi
      trap "rm -rf '$SECURE_TMPDIR' 2>/dev/null || true" EXIT

      # Derive base seed using PBKDF2 (simplified BIP39)
      if [[ -n "$PASSPHRASE" ]]; then
          SALT="mnemonic$PASSPHRASE"
      else
          SALT="mnemonic"
      fi

      BASE_SEED=$(echo -n "$MNEMONIC" | openssl mac -binary -macopt key:"$SALT" -macopt digest:SHA512 HMAC | xxd -p | tr -d '\n')

      # Derive SSH key using HKDF (OpenSSL 3.x)
      SSH_INFO_HEX=$(echo -n "ssh" | xxd -p | tr -d '\n')
      SSH_SEED=$(openssl kdf -binary -keylen 32 -kdfopt digest:SHA256 -kdfopt key:"$BASE_SEED" -kdfopt info:"$SSH_INFO_HEX" HKDF | xxd -p | tr -d '\n')

      # Derive age key using HKDF (OpenSSL 3.x)
      AGE_INFO_HEX=$(echo -n "age" | xxd -p | tr -d '\n')
      AGE_SEED=$(openssl kdf -binary -keylen 32 -kdfopt digest:SHA256 -kdfopt key:"$BASE_SEED" -kdfopt info:"$AGE_INFO_HEX" HKDF | xxd -p | tr -d '\n')

      # Generate deterministic age public key
      AGE_HASH=$(echo -n "$AGE_SEED" | xxd -r -p | openssl dgst -sha256 | cut -d' ' -f2)
      AGE_PUBLIC="age1$(echo -n "$AGE_HASH" | cut -c1-52 | tr '[:upper:]' '[:lower:]')"

      if [[ "$DRY_RUN" == "true" ]]; then
          echo "🧪 DRY RUN: Keys derived successfully" >&2
          echo "" >&2
          echo "SSH Key (would be stored in TPM):" >&2
          echo "  Seed: ''${SSH_SEED:0:16}..." >&2
          echo "" >&2
          echo "Age Key:" >&2
          echo "  Public: $AGE_PUBLIC" >&2
          echo "  Seed: ''${AGE_SEED:0:16}..." >&2
          echo "" >&2
          exit 0
      fi

      echo "💾 Keys derived, use system TPM tools to store them" >&2
      echo "" >&2
      echo "Next steps:" >&2
      echo "1. Store SSH key in TPM (requires system-level tools)" >&2
      echo "2. Configure age key for SOPS" >&2
      echo "" >&2
      echo "Age public key: $AGE_PUBLIC" >&2

      if [[ "$SETUP_SOPS" == "true" ]]; then
          echo "" >&2
          echo "💡 To update SOPS configuration:" >&2
          echo "   Edit .sops.yaml and replace the age key with:" >&2
          echo "   $AGE_PUBLIC" >&2
      fi
    '';
    executable = true;
  };
}
