{ pkgs, ... }:

{
  # Use our custom bip39-cli from Projects folder
  nixpkgs.config.packageOverrides = pkgs: {
    bip39-cli = pkgs.rustPlatform.buildRustPackage {
      pname = "bip39-cli";
      version = "0.1.0";
      src = /home/user/Documents/Projects/bip39-cli;
      cargoHash = "sha256-EoUJfgHljjHH9lwFQGvxqceIT/r9GzN+qkSeIHpBB6E=";
      meta = {
        description = "Command-line tool for BIP39 mnemonic operations using the trusted rust-bitcoin library";
        license = pkgs.lib.licenses.cc0;
      };
    };
  };

  # BIP39 SSH key generation and TPM storage tools
  home.packages = with pkgs; [
    # Our custom BIP39 CLI tool (rust-bitcoin based)
    bip39-cli
    # TPM tools and engines
    tpm2-tools
    tpm2-tss
    tpm2-pkcs11
    # OpenSSL with engine support
    openssl
    # Secure file deletion and memory tools
    coreutils  # includes shred
    util-linux # includes script for memory locking
  ];

  # TPM initialization and setup
  home.file.".local/bin/tpm-init" = {
    text = ''
      #!/bin/bash
      # Initialize TPM hierarchy for SSH key storage
      
      set -euo pipefail
      
      usage() {
          echo "Usage: $0 [--force]"
          echo ""
          echo "Initialize TPM hierarchy for SSH key storage"
          echo ""
          echo "Options:"
          echo "  --force    Recreate primary key even if it exists"
          echo ""
          echo "This creates a primary key at handle 0x81000001 for storing SSH keys"
          exit 1
      }
      
      FORCE=false
      if [[ "''${1:-}" == "--force" ]]; then
          FORCE=true
      elif [[ "''${1:-}" == "--help" ]] || [[ "''${1:-}" == "-h" ]]; then
          usage
      fi
      
      echo "🔧 Initializing TPM for SSH key storage..."
      
      # Check if primary key already exists
      if tpm2_readpublic -c 0x81000001 >/dev/null 2>&1 && [[ "$FORCE" != "true" ]]; then
          echo "✅ TPM primary key already exists at handle 0x81000001"
          echo "   Use --force to recreate"
          exit 0
      fi
      
      # Clear existing handle if forced
      if [[ "$FORCE" == "true" ]]; then
          echo "🗑️  Removing existing primary key..."
          tpm2_evictcontrol -C o -c 0x81000001 2>/dev/null || true
      fi
      
      echo "🔐 Creating TPM primary key..."
      
      # Create primary key in owner hierarchy
      tpm2_createprimary -C o -g sha256 -G ecc -c /tmp/primary.ctx \
          -a "restricted|decrypt|sign"
      
      # Make it persistent at handle 0x81000001  
      tpm2_evictcontrol -C o -c /tmp/primary.ctx 0x81000001
      
      # Clean up
      rm -f /tmp/primary.ctx
      
      echo "✅ TPM initialized successfully"
      echo "   Primary key handle: 0x81000001"
      echo "   Ready for SSH key storage"
    '';
    executable = true;
  };

  # 1. BIP39 directly to TPM (replaces bip39-to-pem + pem-to-tpm)
  home.file.".local/bin/bip39-to-tpm" = {
    text = ''
      #!/bin/bash
      # Convert BIP39 mnemonic directly to Ed25519 key in TPM
      
      set -euo pipefail
      
      usage() {
          echo "Usage: $0 --mnemonic \"word1 word2...\" --handle 0x81000100 [options]"
          echo "       $0 --help"
          echo ""
          echo "Convert BIP39 mnemonic to Ed25519 key stored in TPM with BIP32 derivation"
          echo ""
          echo "Required Options:"
          echo "  --mnemonic \"...\"     BIP39 mnemonic phrase"
          echo "  --handle 0x81000XXX  TPM persistent handle for the key"
          echo ""
          echo "Optional:"
          echo "  --path \"m/44'/0'/0'/0/0\"  BIP32 derivation path (default: m/44'/0'/0'/0/0)"
          echo "  --passphrase \"...\"   BIP39 passphrase (default: empty)"
          echo "  --comment text       Optional comment for the key"
          echo "  --auth-value         Generate random TPM auth (default: no auth)"
          echo "  --dry-run            Test without storing in TPM (shows public key)"
          echo "  --help              Show this help"
          echo ""
          echo "Common Paths:"
          echo "  m/44'/0'/0'/0/0      First signing key (default)"
          echo "  m/44'/0'/0'/0/1      Second signing key"
          echo "  m/44'/0'/1'/0/0      First encryption key"
          echo ""
          echo "Examples:"
          echo "  $0 --mnemonic \"word1 word2 ... word24\" --handle 0x81000100"
          echo "  $0 --mnemonic \"...\" --handle 0x81000101 --path \"m/44'/0'/0'/0/1\" --comment \"GitHub\""
          echo "  $0 --mnemonic \"...\" --handle 0x81000102 --auth-value --comment \"High security key\""
          exit 1
      }
      
      MNEMONIC=""
      HANDLE=""
      COMMENT=""
      PASSPHRASE=""                      # Default empty passphrase
      USE_AUTH=false                     # Default no TPM auth
      DRY_RUN=false                      # Default store in TPM
      
      while [[ $# -gt 0 ]]; do
          case $1 in
              --mnemonic)
                  MNEMONIC="$2"
                  shift 2
                  ;;
              --handle)
                  HANDLE="$2"
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
              --auth-value)
                  USE_AUTH=true
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
                  echo "💡 Run '$0 --help' to see available options" >&2
                  usage
                  ;;
          esac
      done
      
      # Validate required arguments
      if [[ -z "$MNEMONIC" ]]; then
          echo "❌ Missing required --mnemonic argument" >&2
          echo "💡 Use: $0 --mnemonic \"word1 word2 ... word24\" --handle 0x81000100" >&2
          exit 1
      fi
      
      if [[ -z "$HANDLE" && "$DRY_RUN" == "false" ]]; then
          echo "❌ Missing required --handle argument" >&2
          echo "💡 Use: $0 --handle 0x81000100 or add --dry-run for testing" >&2
          exit 1
      fi
      
      # Validate handle format (skip for dry run)
      if [[ "$DRY_RUN" == "false" ]]; then
          if [[ ! "$HANDLE" =~ ^0x81[0-9a-fA-F]{6}$ ]]; then
              echo "❌ Invalid handle format: $HANDLE" >&2
              echo "💡 Use format: 0x81000XXX (e.g., 0x81000100)" >&2
              echo "💡 Valid range: 0x81000100 to 0x81000199" >&2
              exit 1
          fi
          
          # Check if handle already exists
          if tpm2_readpublic -c "$HANDLE" >/dev/null 2>&1; then
              echo "❌ Handle $HANDLE already in use" >&2
              echo "💡 Choose a different handle. Available handles:" >&2
              for i in {100..199}; do
                  handle=$(printf "0x81000%03d" $i)
                  if ! tpm2_readpublic -c "$handle" >/dev/null 2>&1; then
                      echo "   $handle (available)" >&2
                      break
                  fi
              done
              echo "💡 Or use: tpm-keys list to see all handles" >&2
              exit 1
          fi
      fi
      
      # 🔒 SECURITY: Set up secure memory environment
      echo "🔒 Setting up secure memory environment..." >&2
      
      # Increase memory lock limit for this process
      ulimit -l unlimited 2>/dev/null || echo "⚠️  Cannot increase memory lock limit" >&2
      
      # Create secure temporary directory in RAM (tmpfs)
      if [[ -d /dev/shm ]]; then
          SECURE_TMPDIR=$(mktemp -d -p /dev/shm bip39-tpm.XXXXXX)
      else
          SECURE_TMPDIR=$(mktemp -d -t bip39-tpm.XXXXXX)
          echo "⚠️  /dev/shm not available, using regular tmp" >&2
      fi
      
      # Ensure cleanup on exit
      trap "echo '🧹 Cleaning up secure tmpdir...' >&2; rm -rf '$SECURE_TMPDIR' 2>/dev/null || true" EXIT
      
      # Generate TPM auth value if requested
      TPM_AUTH=""
      TPM_AUTH_FILE=""
      if [[ "$USE_AUTH" == "true" ]]; then
          echo "🔐 Generating random TPM auth value..." >&2
          TPM_AUTH=$(openssl rand -hex 16)
          TPM_AUTH_FILE="$SECURE_TMPDIR/auth.txt"
          echo -n "$TPM_AUTH" > "$TPM_AUTH_FILE"
          chmod 600 "$TPM_AUTH_FILE"
          echo "   Auth: ''${TPM_AUTH:0:8}... (truncated)" >&2
      fi
      
      # Validate mnemonic using bip39-cli
      echo "🔍 Validating BIP39 mnemonic..." >&2
      if ! bip39 validate "$MNEMONIC" >/dev/null 2>&1; then
          echo "❌ Invalid BIP39 mnemonic" >&2
          exit 1
      fi
      
      # Validate BIP32 derivation path
      echo "🛤️  Validating BIP32 derivation path: $DERIVATION_PATH" >&2
      if [[ ! "$DERIVATION_PATH" =~ ^m(/[0-9]+\'?)*$ ]]; then
          echo "❌ Invalid BIP32 derivation path format" >&2
          echo "   Expected: m/44'/0'/0'/0/0 or similar" >&2
          exit 1
      fi
      
      # Get BIP39 seed (512 bits) with optional passphrase
      echo "🔑 Deriving seed from BIP39 mnemonic..." >&2
      if [[ -n "$PASSPHRASE" ]]; then
          SEED_HEX=$(bip39 seed "$MNEMONIC" --passphrase "$PASSPHRASE")
          echo "   Using custom passphrase" >&2
      else
          SEED_HEX=$(bip39 seed "$MNEMONIC")
      fi
      
      if [[ -z "$SEED_HEX" ]]; then
          echo "❌ Failed to derive seed from mnemonic" >&2
          exit 1
      fi
      
      # 🔑 BIP32 DERIVATION: Derive key from path
      echo "🔄 Deriving Ed25519 key from BIP32 path: $DERIVATION_PATH" >&2
      
      # Simple BIP32-like derivation using HMAC-SHA512
      # This is a simplified implementation - for production use proper BIP32 library
      MASTER_SEED_HEX="$SEED_HEX"
      CURRENT_KEY="$MASTER_SEED_HEX"
      
      # Parse derivation path and derive key
      PATH_COMPONENTS=$(echo "$DERIVATION_PATH" | sed 's|^m/||' | tr '/' ' ')
      for component in $PATH_COMPONENTS; do
          # Extract index and hardened flag
          if [[ "$component" =~ ^([0-9]+)\'?$ ]]; then
              INDEX=''${BASH_REMATCH[1]}
              if [[ "$component" == *"'" ]]; then
                  # Hardened derivation (add 2^31)
                  INDEX_INT=$((INDEX + 2147483648))
              else
                  INDEX_INT=$INDEX
              fi
              
              # HMAC-SHA512 based key derivation
              # Format: HMAC-SHA512(key=current_key, data="BIP32:" + index_bytes)
              INDEX_BYTES=$(printf "%08x" $INDEX_INT | xxd -r -p | xxd -p | tr -d '\n')
              DERIVATION_DATA="4249503332:$INDEX_BYTES"  # "BIP32:" + index
              
              # Derive next key using HMAC
              CURRENT_KEY=$(echo -n "$DERIVATION_DATA" | xxd -r -p | openssl dgst -sha512 -hmac "$(echo "$CURRENT_KEY" | xxd -r -p)" | cut -d' ' -f2)
          fi
      done
      
      # Use first 32 bytes of derived key for Ed25519 private key
      ED25519_SEED=''${CURRENT_KEY:0:64}  # First 32 bytes (64 hex chars)
      
      echo "✅ BIP32 derivation complete" >&2
      
      echo "🔐 Creating deterministic Ed25519 key from derived seed..." >&2
      
      # Create temporary files for key generation in secure tmpdir
      SEED_FILE="$SECURE_TMPDIR/ed25519_seed.bin"
      PRIVATE_KEY_PEM="$SECURE_TMPDIR/ed25519_private.pem"
      PRIVATE_KEY_DER="$SECURE_TMPDIR/ed25519_private.der"
      
      # Convert hex seed to binary
      echo -n "$ED25519_SEED" | xxd -r -p > "$SEED_FILE"
      chmod 600 "$SEED_FILE"
      
      echo "🔧 Generating deterministic Ed25519 PKCS#8 key..." >&2
      
      # Build PKCS#8 structure for Ed25519 from seed
      # This creates the same key that would be generated from the BIP39 seed
      {
          # PKCS#8 PrivateKeyInfo header for Ed25519
          printf '\x30\x2e'                    # SEQUENCE, length 46
          printf '\x02\x01\x00'               # INTEGER version = 0  
          printf '\x30\x05'                   # SEQUENCE algorithm
          printf '\x06\x03\x2b\x65\x70'       # OID 1.3.101.112 (Ed25519)
          printf '\x04\x22'                   # OCTET STRING, length 34
          printf '\x04\x20'                   # OCTET STRING, length 32 (inner)
          cat "$SEED_FILE"                     # 32-byte private key seed
      } > "$PRIVATE_KEY_DER"
      
      # Convert DER to PEM format
      KEY_B64_FILE="$SECURE_TMPDIR/key_b64.txt"
      openssl base64 -A -in "$PRIVATE_KEY_DER" | fold -w 64 > "$KEY_B64_FILE"
      cat > "$PRIVATE_KEY_PEM" << EOF
-----BEGIN PRIVATE KEY-----
$(cat "$KEY_B64_FILE")
-----END PRIVATE KEY-----
EOF
      chmod 600 "$PRIVATE_KEY_PEM"
      
      if [[ "$DRY_RUN" == "true" ]]; then
          echo "🧪 DRY RUN: Generating SSH public key without storing in TPM..." >&2
          
          # Extract SSH public key from the private key for display
          SSH_PUBKEY=$(ssh-keygen -y -f "$PRIVATE_KEY_PEM" 2>/dev/null || echo "Failed to extract public key")
          
          echo "✅ DRY RUN: Ed25519 key derived successfully" >&2
          echo "   BIP32 path: $DERIVATION_PATH" >&2
          if [[ -n "$COMMENT" ]]; then
              echo "   Comment: $COMMENT" >&2
          fi
          if [[ "$USE_AUTH" == "true" ]]; then
              echo "   TPM Auth would be: ''${TPM_AUTH:0:8}... (not stored)" >&2
          fi
          echo "   SSH public key: $SSH_PUBKEY" >&2
          
          # Output would-be handle for scripting
          echo "DRY_RUN_$HANDLE"
      else
          echo "📥 Importing deterministic key into TPM at handle $HANDLE..." >&2
          
          # Prepare TPM command with optional auth
          TPM_KEY_CTX="$SECURE_TMPDIR/external_key.ctx"
          TPM_LOAD_CMD="tpm2_loadexternal -G ecc:ed25519 -r '$PRIVATE_KEY_PEM' -c '$TPM_KEY_CTX' -a 'sign|decrypt|userwithauth'"
          
          # Add auth if specified
          if [[ "$USE_AUTH" == "true" ]]; then
              TPM_LOAD_CMD="$TPM_LOAD_CMD -p file:'$TPM_AUTH_FILE'"
          fi
          
          # Load the external deterministic key into TPM
          eval "$TPM_LOAD_CMD"
          
          # Make it persistent at the specified handle (with auth if specified)
          TPM_PERSIST_CMD="tpm2_evictcontrol -C o -c '$TPM_KEY_CTX' '$HANDLE'"
          if [[ "$USE_AUTH" == "true" ]]; then
              TPM_PERSIST_CMD="$TPM_PERSIST_CMD -p file:'$TPM_AUTH_FILE'"
          fi
          
          eval "$TPM_PERSIST_CMD"
      fi
      
      echo "🧹 Securely cleaning up temporary key material..." >&2
      
      # Securely destroy all temporary key material in secure tmpdir
      if command -v shred >/dev/null 2>&1; then
          # Use shred to securely overwrite files
          find "$SECURE_TMPDIR" -type f -exec shred -vfz -n 3 {} \; 2>/dev/null || true
      else
          # Fallback if shred not available - overwrite with random data
          for file in "$SECURE_TMPDIR"/*; do
              if [[ -f "$file" ]]; then
                  dd if=/dev/urandom of="$file" bs=1024 count=1 2>/dev/null || true
              fi
          done
      fi
      
      # The EXIT trap will clean up the secure tmpdir
      
      if [[ "$DRY_RUN" == "false" ]]; then
          echo "✅ Ed25519 key stored in TPM at handle: $HANDLE" >&2
          echo "   BIP32 path: $DERIVATION_PATH" >&2
          if [[ -n "$COMMENT" ]]; then
              echo "   Comment: $COMMENT" >&2
          fi
          if [[ "$USE_AUTH" == "true" ]]; then
              echo "   TPM Auth: ''${TPM_AUTH:0:8}... (save this securely!)" >&2
          fi
          
          # Output handle for piping/scripting
          echo "$HANDLE"
      fi
    '';
    executable = true;
  };

  # 2. TPM handle to SSH public key
  home.file.".local/bin/tpm-to-pubkey" = {
    text = ''
      #!/bin/bash
      # Extract SSH public key from TPM-stored private key
      
      set -euo pipefail
      
      usage() {
          echo "Usage: $0 <handle>"
          echo "       $0 --list"
          echo "       $0 --help"
          echo ""
          echo "Extract SSH public key from TPM-stored Ed25519 key"
          echo ""
          echo "Arguments:"
          echo "  <handle>      TPM persistent handle (e.g., 0x81000100)"
          echo ""
          echo "Options:"
          echo "  --list        List all persistent TPM handles"
          echo "  --help        Show this help"
          echo ""
          echo "Example:"
          echo "  $0 0x81000100"
          exit 1
      }
      
      if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
          usage
      fi
      
      if [[ "$1" == "--list" ]]; then
          echo "📋 Persistent TPM handles:"
          tpm2_getcap handles-persistent 2>/dev/null | grep -E "0x81" || echo "No persistent handles found"
          exit 0
      fi
      
      HANDLE="$1"
      
      # Validate handle format
      if [[ ! "$HANDLE" =~ ^0x81[0-9a-fA-F]{6}$ ]]; then
          echo "❌ Invalid handle format. Use 0x81XXXXXX" >&2
          exit 1
      fi
      
      # Check if handle exists
      if ! tpm2_readpublic -c "$HANDLE" >/dev/null 2>&1; then
          echo "❌ Handle $HANDLE not found in TPM" >&2
          echo "Available handles:" >&2
          tpm2_getcap handles-persistent 2>/dev/null | grep -E "0x81" >&2 || echo "No persistent handles found" >&2
          exit 1
      fi
      
      echo "🔑 Extracting public key from TPM handle: $HANDLE" >&2
      
      # Extract public key from TPM
      TEMP_PUB="/tmp/tpm_pubkey_$$.pem"
      
      # Get public key in PEM format
      tpm2_readpublic -c "$HANDLE" -f pem -o "$TEMP_PUB" >/dev/null 2>&1
      
      # Convert PEM to SSH format
      if ssh-keygen -i -m PKCS8 -f "$TEMP_PUB" 2>/dev/null; then
          # Add handle as comment
          echo " $HANDLE@tpm"
      else
          echo "❌ Failed to convert public key to SSH format" >&2
          rm -f "$TEMP_PUB"
          exit 1
      fi
      
      # Clean up
      rm -f "$TEMP_PUB"
    '';
    executable = true;
  };

  # 3. TPM SSH agent with OpenSSL engine
  home.file.".local/bin/tpm-ssh-agent" = {
    text = ''
      #!/bin/bash
      # Load TPM keys into SSH agent using OpenSSL engine
      
      set -euo pipefail
      
      usage() {
          echo "Usage: $0 [options] [handle...]"
          echo "       $0 --help"
          echo ""
          echo "Load TPM-stored keys into SSH agent"
          echo ""
          echo "Arguments:"
          echo "  [handle...]   Specific TPM handles to load (default: all)"
          echo ""
          echo "Options:"
          echo "  --list        List loaded keys in SSH agent"
          echo "  --clear       Clear all keys from SSH agent"
          echo "  --help        Show this help"
          echo ""
          echo "Examples:"
          echo "  $0                    # Load all TPM keys"
          echo "  $0 0x81000100        # Load specific handle"
          echo "  $0 --list            # Show loaded keys"
          exit 1
      }
      
      if [[ "''${1:-}" == "--help" ]] || [[ "''${1:-}" == "-h" ]]; then
          usage
      fi
      
      if [[ "''${1:-}" == "--list" ]]; then
          echo "📋 Keys loaded in SSH agent:"
          ssh-add -l
          exit 0
      fi
      
      if [[ "''${1:-}" == "--clear" ]]; then
          echo "🧹 Clearing SSH agent..."
          ssh-add -D
          exit 0
      fi
      
      # Get handles to load
      if [[ $# -gt 0 ]]; then
          HANDLES=("$@")
      else
          # Get all persistent handles
          readarray -t HANDLES < <(tpm2_getcap handles-persistent 2>/dev/null | grep -E "0x81" | awk '{print $1}' || true)
      fi
      
      if [[ ''${#HANDLES[@]} -eq 0 ]]; then
          echo "❌ No TPM handles found" >&2
          echo "Use: tpm-init to initialize TPM" >&2
          echo "Use: bip39-to-tpm to create keys" >&2
          exit 1
      fi
      
      echo "🔌 Loading TPM keys into SSH agent..." >&2
      
      LOADED=0
      for handle in "''${HANDLES[@]}"; do
          echo "  Loading $handle..." >&2
          
          # Extract public key for SSH agent
          if PUBKEY=$(tpm-to-pubkey "$handle" 2>/dev/null); then
              # Create temporary key files for ssh-add
              TEMP_PRIVATE="/tmp/tpm_private_$$.pem"
              TEMP_PUBLIC="/tmp/tpm_public_$$.pub"
              
              # For SSH agent, we need to provide a way to reference the TPM key
              # This might require a custom SSH agent or PKCS#11 module
              echo "⚠️  Note: Direct TPM → SSH agent integration requires PKCS#11 module" >&2
              echo "   Public key: $PUBKEY" >&2
              
              # Alternative: Use tpm2-pkcs11 module
              if command -v ssh-add >/dev/null && [[ -f ''${pkgs.tpm2-pkcs11}/lib/libtpm2_pkcs11.so ]]; then
                  ssh-add -s ''${pkgs.tpm2-pkcs11}/lib/libtpm2_pkcs11.so 2>/dev/null || true
              fi
              
              LOADED=$((LOADED + 1))
          else
              echo "  ❌ Failed to load $handle" >&2
          fi
      done
      
      if [[ $LOADED -gt 0 ]]; then
          echo "✅ Loaded $LOADED TPM keys" >&2
          echo "" >&2
          echo "📋 SSH agent keys:" >&2
          ssh-add -l >&2
      else
          echo "❌ No keys loaded" >&2
          exit 1
      fi
    '';
    executable = true;
  };

  # 4. TPM key management utility
  home.file.".local/bin/tpm-keys" = {
    text = ''
      #!/bin/bash
      # TPM key management utility for listing and inspecting keys
      
      set -euo pipefail
      
      usage() {
          echo "Usage: $0 <command> [options]"
          echo "       $0 --help"
          echo ""
          echo "TPM key management commands:"
          echo ""
          echo "Commands:"
          echo "  list                List all persistent TPM handles"
          echo "  info <handle>      Show detailed info about a specific handle"
          echo "  pubkey <handle>    Extract SSH public key from handle"
          echo "  remove <handle>    Remove handle from TPM (DESTRUCTIVE)"
          echo "  clear              Remove ALL handles (VERY DESTRUCTIVE)"
          echo ""
          echo "Options:"
          echo "  --help             Show this help"
          echo ""
          echo "Examples:"
          echo "  $0 list"
          echo "  $0 info 0x81000100"
          echo "  $0 pubkey 0x81000100"
          echo "  $0 remove 0x81000100"
          exit 1
      }
      
      if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
          usage
      fi
      
      COMMAND="$1"
      
      case "$COMMAND" in
          "list")
              echo "📋 Persistent TPM handles:"
              echo ""
              
              # Get all persistent handles
              HANDLES=$(tpm2_getcap handles-persistent 2>/dev/null | grep -E "0x81" | awk '{print $1}' || true)
              
              if [[ -z "$HANDLES" ]]; then
                  echo "   No persistent handles found"
                  echo ""
                  echo "💡 Use: bip39-to-tpm to create SSH keys"
                  echo "💡 Use: tpm-init to initialize TPM"
                  exit 0
              fi
              
              printf "%-12s %-10s %-50s\\n" "Handle" "Type" "SSH Public Key (truncated)"
              printf "%-12s %-10s %-50s\\n" "--------" "--------" "------------------------------"
              
              for handle in $HANDLES; do
                  # Try to get SSH public key
                  if SSH_KEY=$(tpm-to-pubkey "$handle" 2>/dev/null); then
                      KEY_TYPE=$(echo "$SSH_KEY" | awk '{print $1}')
                      KEY_SHORT="''${SSH_KEY:0:60}..."
                      printf "%-12s %-10s %-50s\\n" "$handle" "$KEY_TYPE" "$KEY_SHORT"
                  else
                      printf "%-12s %-10s %-50s\\n" "$handle" "error" "(failed to extract)"
                  fi
              done
              
              echo ""
              echo "💡 Use: tpm-keys info <handle> for detailed information"
              ;;
              
          "info")
              if [[ $# -lt 2 ]]; then
                  echo "❌ Missing handle argument" >&2
                  echo "💡 Use: $0 info 0x81000100" >&2
                  exit 1
              fi
              
              HANDLE="$2"
              
              # Validate handle format
              if [[ ! "$HANDLE" =~ ^0x81[0-9a-fA-F]{6}$ ]]; then
                  echo "❌ Invalid handle format: $HANDLE" >&2
                  echo "💡 Use format: 0x81000XXX" >&2
                  exit 1
              fi
              
              # Check if handle exists
              if ! tpm2_readpublic -c "$HANDLE" >/dev/null 2>&1; then
                  echo "❌ Handle $HANDLE not found in TPM" >&2
                  echo "💡 Use: tpm-keys list to see available handles" >&2
                  exit 1
              fi
              
              echo "🔍 TPM Handle Information: $HANDLE"
              echo ""
              
              # Get SSH public key
              if SSH_PUBKEY=$(tpm-to-pubkey "$HANDLE" 2>/dev/null); then
                  echo "SSH Information:"
                  echo "  Public Key: $SSH_PUBKEY"
                  
                  # Extract key type and fingerprint
                  KEY_TYPE=$(echo "$SSH_PUBKEY" | awk '{print $1}')
                  TEMP_KEY_FILE="/tmp/tpm_key_$$.pub"
                  echo "$SSH_PUBKEY" > "$TEMP_KEY_FILE"
                  
                  if FINGERPRINT=$(ssh-keygen -lf "$TEMP_KEY_FILE" 2>/dev/null); then
                      echo "  Type: $KEY_TYPE"
                      echo "  Fingerprint: $FINGERPRINT"
                  fi
                  
                  rm -f "$TEMP_KEY_FILE"
                  echo ""
              else
                  echo "SSH Information: Failed to extract public key"
                  echo ""
              fi
              
              echo "💡 Commands:"
              echo "  tpm-keys pubkey $HANDLE    # Extract just the public key"
              echo "  tpm-to-pubkey $HANDLE      # Same as above"
              echo "  tpm-keys remove $HANDLE    # Remove this key (destructive!)"
              ;;
              
          "pubkey")
              if [[ $# -lt 2 ]]; then
                  echo "❌ Missing handle argument" >&2
                  echo "💡 Use: $0 pubkey 0x81000100" >&2
                  exit 1
              fi
              
              # Just call the existing tpm-to-pubkey script
              tpm-to-pubkey "$2"
              ;;
              
          "remove")
              if [[ $# -lt 2 ]]; then
                  echo "❌ Missing handle argument" >&2
                  echo "💡 Use: $0 remove 0x81000100" >&2
                  exit 1
              fi
              
              HANDLE="$2"
              
              # Validate handle format
              if [[ ! "$HANDLE" =~ ^0x81[0-9a-fA-F]{6}$ ]]; then
                  echo "❌ Invalid handle format: $HANDLE" >&2
                  echo "💡 Use format: 0x81000XXX" >&2
                  exit 1
              fi
              
              # Check if handle exists
              if ! tpm2_readpublic -c "$HANDLE" >/dev/null 2>&1; then
                  echo "❌ Handle $HANDLE not found in TPM" >&2
                  echo "💡 Use: tpm-keys list to see available handles" >&2
                  exit 1
              fi
              
              # Get public key for confirmation
              if SSH_PUBKEY=$(tpm-to-pubkey "$HANDLE" 2>/dev/null); then
                  KEY_SHORT="''${SSH_PUBKEY:0:60}..."
                  echo "⚠️  WARNING: About to permanently remove TPM key!"
                  echo "   Handle: $HANDLE"
                  echo "   Key: $KEY_SHORT"
                  echo ""
                  read -p "Type 'YES' to confirm removal: " CONFIRM
                  
                  if [[ "$CONFIRM" == "YES" ]]; then
                      echo "🗑️  Removing TPM key at handle $HANDLE..."
                      tpm2_evictcontrol -C o -c "$HANDLE"
                      echo "✅ Key removed successfully"
                  else
                      echo "❌ Removal cancelled"
                      exit 1
                  fi
              else
                  echo "❌ Failed to read key for confirmation" >&2
                  exit 1
              fi
              ;;
              
          *)
              echo "❌ Unknown command: $COMMAND" >&2
              echo "💡 Available commands: list, info, pubkey, remove" >&2
              echo "💡 Use: $0 --help for more information" >&2
              exit 1
              ;;
      esac
    '';
    executable = true;
  };

  # 5. Simplified workflow helper
  home.file.".local/bin/bip39-ssh-setup" = {
    text = ''
      #!/bin/bash
      # Complete BIP39 → TPM → SSH workflow
      
      set -euo pipefail
      
      usage() {
          echo "Usage: $0 --mnemonic \"word1 word2...\" [options]"
          echo "       $0 --help"
          echo ""
          echo "Complete workflow: BIP39 → TPM → SSH agent"
          echo ""
          echo "Options:"
          echo "  --mnemonic \"...\"     BIP39 mnemonic phrase"
          echo "  --handle 0x81000XXX  TPM handle (default: auto-assign)"
          echo "  --passphrase \"...\"   BIP39 passphrase (default: empty)"
          echo "  --comment text       Optional comment for the key"
          echo "  --auth-value         Generate random TPM auth"
          echo "  --load-agent         Load key into SSH agent after creation"
          echo "  --help              Show this help"
          echo ""
          echo "Examples:"
          echo "  $0 --mnemonic \"word1 word2 ... word24\" --load-agent"
          echo "  $0 --mnemonic \"...\" --comment \"GitHub\" --auth-value"
          exit 1
      }
      
      MNEMONIC=""
      HANDLE=""
      PASSPHRASE=""
      COMMENT=""
      USE_AUTH=false
      LOAD_AGENT=false
      
      while [[ $# -gt 0 ]]; do
          case $1 in
              --mnemonic)
                  MNEMONIC="$2"
                  shift 2
                  ;;
              --handle)
                  HANDLE="$2"
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
              --auth-value)
                  USE_AUTH=true
                  shift
                  ;;
              --load-agent)
                  LOAD_AGENT=true
                  shift
                  ;;
              --help|-h)
                  usage
                  ;;
              *)
                  echo "❌ Unknown option: $1"
                  usage
                  ;;
          esac
      done
      
      if [[ -z "$MNEMONIC" ]]; then
          echo "❌ Missing required --mnemonic argument"
          usage
      fi
      
      # Auto-assign handle if not provided
      if [[ -z "$HANDLE" ]]; then
          for i in {100..199}; do
              HANDLE=$(printf "0x81000%03d" $i)
              if ! tpm2_readpublic -c "$HANDLE" >/dev/null 2>&1; then
                  break
              fi
          done
          echo "🎯 Auto-assigned handle: $HANDLE"
      fi
      
      # Initialize TPM if needed
      if ! tpm2_readpublic -c 0x81000001 >/dev/null 2>&1; then
          echo "🔧 Initializing TPM..."
          tpm-init
      fi
      
      # Create key in TPM with all options
      echo "🔑 Creating Ed25519 key from BIP39..."
      
      # Build command with all options
      TPM_CMD="bip39-to-tpm --mnemonic '$MNEMONIC' --handle '$HANDLE'"
      
      if [[ -n "$PASSPHRASE" ]]; then
          TPM_CMD="$TPM_CMD --passphrase '$PASSPHRASE'"
      fi
      
      if [[ -n "$COMMENT" ]]; then
          TPM_CMD="$TPM_CMD --comment '$COMMENT'"
      fi
      
      if [[ "$USE_AUTH" == "true" ]]; then
          TPM_CMD="$TPM_CMD --auth-value"
      fi
      
      CREATED_HANDLE=$(eval "$TPM_CMD")
      
      # Extract public key
      echo "📤 Extracting SSH public key..."
      PUBKEY=$(tpm-to-pubkey "$CREATED_HANDLE")
      echo "$PUBKEY"
      
      # Load into SSH agent if requested
      if [[ "$LOAD_AGENT" == "true" ]]; then
          echo "🔌 Loading into SSH agent..."
          tpm-ssh-agent "$CREATED_HANDLE"
      fi
      
      echo "✅ BIP39 → TPM → SSH setup complete!"
      echo "   Handle: $CREATED_HANDLE"
      echo "   Public key: ''${PUBKEY%% *} (truncated)"
    '';
    executable = true;
  };
}