{ pkgs, ... }:

{
  # BIP39 SSH key generation and TPM storage tools
  home.packages = with pkgs; [
    python3Packages.mnemonic
    python3Packages.cryptography
    python3Packages.ecdsa
    tpm2-tools
    tpm2-pkcs11
  ];

  # BIP39 SSH key derivation script
  home.file.".local/bin/bip39-ssh-keygen" = {
    text = ''
      #!/usr/bin/env python3
      """
      BIP39-based SSH key generation with TPM storage support
      
      This script generates SSH keypairs from BIP39 mnemonics using
      deterministic key derivation (BIP32/BIP44).
      """
      
      import os
      import sys
      import hashlib
      import hmac
      import argparse
      from pathlib import Path
      from mnemonic import Mnemonic
      from cryptography.hazmat.primitives import hashes, serialization
      from cryptography.hazmat.primitives.asymmetric import ed25519, rsa
      from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
      
      class BIP39SSHKeyGen:
          def __init__(self):
              self.mnemo = Mnemonic("english")
              
          def generate_mnemonic(self, strength=256):
              """Generate a new BIP39 mnemonic (24 words for 256-bit entropy)"""
              return self.mnemo.generate(strength=strength)
              
          def mnemonic_to_seed(self, mnemonic, passphrase=""):
              """Convert mnemonic to seed using PBKDF2"""
              return self.mnemo.to_seed(mnemonic, passphrase)
              
          def derive_key_material(self, seed, path="m/44'/0'/0'/0/0", key_type="ed25519"):
              """
              Derive key material from seed using BIP32-like derivation
              
              Args:
                  seed: Master seed from mnemonic
                  path: Derivation path (e.g., "m/44'/0'/0'/0/0")
                  key_type: "ed25519" or "rsa"
              """
              # Simplified derivation - in production, use proper BIP32 implementation
              path_hash = hashlib.sha256(f"{path}:{key_type}".encode()).digest()
              key_material = hmac.new(seed, path_hash, hashlib.sha512).digest()
              
              if key_type == "ed25519":
                  # Use first 32 bytes for Ed25519 private key
                  private_key = ed25519.Ed25519PrivateKey.from_private_bytes(key_material[:32])
                  return private_key
              elif key_type == "rsa":
                  # Use key material to seed RSA generation
                  # This is a simplified approach - use proper entropy in production
                  from cryptography.hazmat.primitives.asymmetric import rsa
                  # For deterministic RSA, we'd need a more complex implementation
                  raise NotImplementedError("Deterministic RSA generation needs proper implementation")
              else:
                  raise ValueError(f"Unsupported key type: {key_type}")
                  
          def generate_ssh_keypair(self, mnemonic, passphrase="", path="m/44'/0'/0'/0/0", 
                                 key_type="ed25519", comment=""):
              """Generate SSH keypair from mnemonic"""
              seed = self.mnemonic_to_seed(mnemonic, passphrase)
              private_key = self.derive_key_material(seed, path, key_type)
              
              # Generate SSH format keys
              private_pem = private_key.private_bytes(
                  encoding=serialization.Encoding.PEM,
                  format=serialization.PrivateFormat.OpenSSH,
                  encryption_algorithm=serialization.NoEncryption()
              )
              
              public_key = private_key.public_key()
              public_ssh = public_key.public_bytes(
                  encoding=serialization.Encoding.OpenSSH,
                  format=serialization.PublicFormat.OpenSSH
              )
              
              if comment:
                  public_ssh += f" {comment}".encode()
                  
              return private_pem, public_ssh
              
          def save_keypair(self, private_key, public_key, key_path):
              """Save keypair to files with proper permissions"""
              key_path = Path(key_path)
              
              # Write private key
              with open(key_path, 'wb') as f:
                  f.write(private_key)
              os.chmod(key_path, 0o600)
              
              # Write public key
              with open(f"{key_path}.pub", 'wb') as f:
                  f.write(public_key)
              os.chmod(f"{key_path}.pub", 0o644)
              
              print(f"✅ Keypair saved:")
              print(f"   Private: {key_path}")
              print(f"   Public:  {key_path}.pub")
              
      def main():
          parser = argparse.ArgumentParser(description="BIP39 SSH Key Generator")
          parser.add_argument("--generate-mnemonic", action="store_true",
                            help="Generate a new mnemonic")
          parser.add_argument("--mnemonic", type=str,
                            help="Use existing mnemonic (space-separated words)")
          parser.add_argument("--passphrase", type=str, default="",
                            help="Optional passphrase for mnemonic")
          parser.add_argument("--path", type=str, default="m/44'/0'/0'/0/0",
                            help="BIP32 derivation path")
          parser.add_argument("--key-type", choices=["ed25519"], default="ed25519",
                            help="Key type (currently only ed25519 supported)")
          parser.add_argument("--output", type=str, default="~/.ssh/id_bip39_ed25519",
                            help="Output file path")
          parser.add_argument("--comment", type=str, default="",
                            help="Comment for public key")
          
          args = parser.parse_args()
          
          keygen = BIP39SSHKeyGen()
          
          if args.generate_mnemonic:
              mnemonic = keygen.generate_mnemonic()
              print("🔐 Generated BIP39 Mnemonic:")
              print(f"   {mnemonic}")
              print("⚠️  IMPORTANT: Store this mnemonic securely!")
              print("   Write it down on paper and store in a safe place.")
              return
              
          if not args.mnemonic:
              print("❌ Error: Must provide --mnemonic or use --generate-mnemonic")
              return 1
              
          try:
              # Validate mnemonic
              if not keygen.mnemo.check(args.mnemonic):
                  print("❌ Error: Invalid mnemonic")
                  return 1
                  
              # Generate keypair
              private_key, public_key = keygen.generate_ssh_keypair(
                  args.mnemonic, args.passphrase, args.path, 
                  args.key_type, args.comment
              )
              
              # Save to file
              output_path = Path(args.output).expanduser()
              output_path.parent.mkdir(parents=True, exist_ok=True)
              keygen.save_keypair(private_key, public_key, output_path)
              
              print(f"🔑 SSH keypair generated from BIP39 mnemonic")
              print(f"   Derivation path: {args.path}")
              print(f"   Key type: {args.key_type}")
              
          except Exception as e:
              print(f"❌ Error: {e}")
              return 1
              
      if __name__ == "__main__":
          sys.exit(main())
    '';
    executable = true;
  };

  # TPM key storage helper script
  home.file.".local/bin/ssh-to-tpm" = {
    text = ''
      #!/bin/bash
      # Store SSH private key in TPM using tpm2-pkcs11
      
      set -euo pipefail
      
      usage() {
          echo "Usage: $0 <ssh-private-key-file> <key-id>"
          echo "Example: $0 ~/.ssh/id_bip39_ed25519 bip39-ssh-001"
          exit 1
      }
      
      if [[ $# -lt 2 ]]; then
          usage
      fi
      
      SSH_KEY="$1"
      KEY_ID="$2"
      
      if [[ ! -f "$SSH_KEY" ]]; then
          echo "❌ SSH key file not found: $SSH_KEY"
          exit 1
      fi
      
      echo "🔐 Storing SSH key in TPM..."
      echo "   Key file: $SSH_KEY"
      echo "   Key ID: $KEY_ID"
      
      # Initialize TPM2-PKCS11 if needed
      if [[ ! -f ~/.local/share/tpm2_pkcs11/tpm2_pkcs11.sqlite3 ]]; then
          echo "📦 Initializing TPM2-PKCS11..."
          mkdir -p ~/.local/share/tpm2_pkcs11
          tpm2_ptool init
      fi
      
      # Create token if it doesn't exist
      if ! tpm2_ptool listtoken | grep -q "bip39-ssh"; then
          echo "🏷️  Creating TPM token..."
          tpm2_ptool addtoken --pid=1 --label=bip39-ssh --userpin=123456 --sopin=123456
      fi
      
      # Import SSH key to TPM
      echo "📥 Importing SSH key to TPM..."
      tpm2_ptool addkey --algorithm=ecc --label="$KEY_ID" \
          --userpin=123456 --key-label="$KEY_ID" \
          --private="$SSH_KEY"
      
      echo "✅ SSH key stored in TPM with ID: $KEY_ID"
      echo "💡 To use: ssh-add -s ${pkgs.tpm2-pkcs11}/lib/libtpm2_pkcs11.so"
      
      # Show stored keys
      echo "📋 TPM-stored keys:"
      tpm2_ptool listkey --label=bip39-ssh
    '';
    executable = true;
  };

  # BIP39 key management helper
  home.file.".local/bin/bip39-ssh-manager" = {
    text = ''
      #!/bin/bash
      # BIP39 SSH Key Management Helper
      
      set -euo pipefail
      
      SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
      
      usage() {
          echo "BIP39 SSH Key Manager"
          echo "===================="
          echo ""
          echo "Commands:"
          echo "  generate-mnemonic    Generate new BIP39 mnemonic"
          echo "  create-key          Create SSH key from mnemonic"
          echo "  store-in-tpm        Store SSH key in TPM"
          echo "  list-tpm-keys       List keys stored in TPM"
          echo "  load-tpm-agent      Load TPM keys into SSH agent"
          echo ""
          echo "Examples:"
          echo "  $0 generate-mnemonic"
          echo "  $0 create-key"
          echo "  $0 store-in-tpm ~/.ssh/id_bip39_ed25519 my-key"
          echo "  $0 load-tpm-agent"
      }
      
      generate_mnemonic() {
          echo "🔐 Generating new BIP39 mnemonic..."
          bip39-ssh-keygen --generate-mnemonic
      }
      
      create_key() {
          echo "🔑 Creating SSH key from BIP39 mnemonic..."
          echo "Enter your BIP39 mnemonic (space-separated):"
          read -r mnemonic
          
          echo "Enter derivation path (default: m/44'/0'/0'/0/0):"
          read -r path
          path=''${path:-"m/44'/0'/0'/0/0"}
          
          echo "Enter key comment (optional):"
          read -r comment
          
          output_file="$HOME/.ssh/id_bip39_ed25519_$(date +%Y%m%d)"
          
          bip39-ssh-keygen \
              --mnemonic "$mnemonic" \
              --path "$path" \
              --comment "$comment" \
              --output "$output_file"
      }
      
      store_in_tpm() {
          if [[ $# -lt 2 ]]; then
              echo "Usage: $0 store-in-tpm <key-file> <key-id>"
              exit 1
          fi
          ssh-to-tpm "$1" "$2"
      }
      
      list_tpm_keys() {
          echo "📋 TPM-stored SSH keys:"
          if command -v tpm2_ptool >/dev/null; then
              tpm2_ptool listtoken 2>/dev/null || echo "No TPM tokens found"
          else
              echo "tpm2_ptool not available"
          fi
      }
      
      load_tpm_agent() {
          echo "🔌 Loading TPM keys into SSH agent..."
          if ssh-add -s ${pkgs.tpm2-pkcs11}/lib/libtpm2_pkcs11.so; then
              echo "✅ TPM keys loaded into SSH agent"
              ssh-add -l
          else
              echo "❌ Failed to load TPM keys"
          fi
      }
      
      case "''${1:-}" in
          generate-mnemonic) generate_mnemonic ;;
          create-key) create_key ;;
          store-in-tpm) shift; store_in_tpm "$@" ;;
          list-tpm-keys) list_tmp_keys ;;
          load-tpm-agent) load_tpm_agent ;;
          *) usage ;;
      esac
    '';
    executable = true;
  };
}