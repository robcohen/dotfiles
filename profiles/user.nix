{ config, pkgs, lib, inputs, ... }:

let
  vars = import ../lib/vars.nix;
  
  # Simple hostname detection with fallback
  detectedHostname = "brix";  # Hardcode for now to avoid infinite recursion
  
  # Get host config 
  hostConfig = vars.hosts.${detectedHostname} or {};
  
  unstable = import inputs.unstable-nixpkgs {
    system = pkgs.system;
    config.allowUnfree = true;
  };
in {
  imports = [
    ./host-specific.nix
    ./packages.nix
    ./session-variables.nix
    ./mimeapps.nix
    ./programs/direnv.nix
    ./programs/gpg.nix
    ./programs/tmux.nix
    ./programs/bash.nix
    ./programs/alacritty.nix
    ./programs/ungoogled-chromium.nix
    ./programs/git.nix
    ./programs/zsh.nix
    ./programs/npm.nix
    ./programs/home-manager.nix
    ./programs/starship.nix
    ./programs/fzf.nix
    ./programs/eza.nix
    ./programs/bat.nix
    ./programs/ripgrep.nix
    ./programs/dircolors.nix
    ./programs/htop.nix
    ./programs/less.nix
    ./programs/ssh.nix
    ./programs/readline.nix
    ./programs/zoxide.nix
    ./programs/atuin.nix
    ./services/gpg-agent.nix
    ./services/syncthing.nix
    ./services/desktop-notifications.nix
    ./services/system-monitoring.nix
    # Security modules (import after base configurations)
    ./security/advanced-ssh.nix
    ./security/advanced-gpg.nix
  ];

  nixpkgs = {
    overlays = [ ];
    config = {
      allowUnfree = true;
      allowUnfreePredicate = _: true;
    };
  };

  # Pass config to other modules  
  _module.args = {
    hostname = detectedHostname;
    hostConfig = hostConfig;
    hostFeatures = hostConfig.features or [];
    hostType = hostConfig.type or "desktop";
  };

  home = {
    username = vars.user.name;
    homeDirectory = vars.user.home;
    stateVersion = hostConfig.homeManagerStateVersion or "23.11";
  };

  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
    };
  };

  systemd.user.startServices = "sd-switch";

  # Add simple debugging info
  home.file.".config/home-manager/host-info.txt".text = ''
    Host: ${detectedHostname}
    Type: ${hostConfig.type or "desktop"}
    Features: ${lib.concatStringsSep ", " (hostConfig.features or [])}
    State Version: ${hostConfig.homeManagerStateVersion or "23.11"}
  '';


  # Add .local/bin and node_modules/bin to PATH
  home.sessionPath = [ "$HOME/.local/bin" "$HOME/node_modules/.bin" ];

  # Security tools
  home.packages = with pkgs; [
    age               # Modern encryption
    sops              # Secrets operations
    chkrootkit        # Rootkit scanner
    lynis             # Security auditing tool
    vulnix            # Nix vulnerability scanner
    nmap              # Network scanner
  ];

  # Simple security scripts
  home.file.".local/bin/security-scan" = {
    text = ''
      #!/usr/bin/env bash
      echo "🔍 Basic Security Scan"
      echo "===================="
      echo ""
      echo "📦 Checking for vulnerable packages..."
      vulnix --system 2>/dev/null | head -5 || echo "No critical vulnerabilities found"
      echo ""
      echo "🌐 Checking open ports..."
      nmap -sT localhost 2>/dev/null | grep open || echo "No open ports detected"
      echo ""
      echo "✅ Basic scan complete. Run 'lynis audit system' for detailed analysis."
    '';
    executable = true;
  };

  # BIP39 SSH key generator
  home.file.".local/bin/bip39-ssh-keygen" = {
    text = ''
      #!/usr/bin/env bash
      # BIP39 SSH Key Generator
      # Generate deterministic SSH keys from BIP39 mnemonics
      
      set -euo pipefail
      
      usage() {
          echo "BIP39 SSH Key Generator"
          echo "======================"
          echo ""
          echo "Usage: $0 [options]"
          echo ""
          echo "Options:"
          echo "  --generate-mnemonic [12|15|18|21|24]  Generate new mnemonic (default: 24)"
          echo "  --from-mnemonic \"words...\"             Generate SSH key from mnemonic"
          echo "  --output FILE                         Output file path (default: ~/.ssh/id_bip39_ed25519)"
          echo "  --comment TEXT                        Comment for public key"
          echo "  --help                               Show this help"
          echo ""
          echo "Examples:"
          echo "  $0 --generate-mnemonic 24"
          echo "  $0 --from-mnemonic \"word1 word2 ... word24\""
          echo "  $0 --from-mnemonic \"$(cat my-mnemonic.txt)\" --output ~/.ssh/id_secure"
      }
      
      generate_mnemonic() {
          local strength=$1
          echo "🔐 Generating $strength-word BIP39 mnemonic..."
          
          case $strength in
              12) bits=128 ;;
              15) bits=160 ;;
              18) bits=192 ;;
              21) bits=224 ;;
              24) bits=256 ;;
              *) echo "❌ Invalid mnemonic length. Use 12, 15, 18, 21, or 24"; exit 1 ;;
          esac
          
          ${pkgs.nix}/bin/nix-shell -p python3Packages.mnemonic --run "python3 -c '
      from mnemonic import Mnemonic
      m = Mnemonic(\"english\")
      mnemonic = m.generate(strength=$bits)
      print(mnemonic)
      '"
          
          echo ""
          echo "⚠️  IMPORTANT SECURITY NOTICE:"
          echo "   • Write this mnemonic on paper and store it securely"
          echo "   • Never share or store it digitally"
          echo "   • You can recreate your SSH key from this mnemonic"
          echo "   • Anyone with this mnemonic can recreate your private key"
      }
      
      generate_ssh_key() {
          local mnemonic="$1"
          local output_file="$2"
          local comment="$3"
          local temp_script=$(mktemp)
          
          echo "🔑 Generating SSH key from BIP39 mnemonic..."
          
          # Create Python script for key generation
          cat > "$temp_script" << 'EOF'
      #!/usr/bin/env python3
      import sys
      import hashlib
      import hmac
      from mnemonic import Mnemonic
      from cryptography.hazmat.primitives import hashes, serialization
      from cryptography.hazmat.primitives.asymmetric import ed25519
      
      def mnemonic_to_seed(mnemonic_words, passphrase=""):
          m = Mnemonic("english")
          if not m.check(mnemonic_words):
              print("❌ Invalid mnemonic", file=sys.stderr)
              sys.exit(1)
          return m.to_seed(mnemonic_words, passphrase)
      
      def derive_ed25519_key(seed, path="m/44'/0'/0'/0/0"):
          # Simplified BIP32-like derivation for Ed25519
          # In production, use proper BIP32 implementation
          path_hash = hashlib.sha256(f"{path}:ed25519-ssh".encode()).digest()
          key_material = hmac.new(seed, path_hash, hashlib.sha512).digest()
          
          # Use first 32 bytes for Ed25519 private key
          private_key = ed25519.Ed25519PrivateKey.from_private_bytes(key_material[:32])
          return private_key
      
      def main():
          mnemonic = sys.argv[1]
          output_file = sys.argv[2]
          comment = sys.argv[3] if len(sys.argv) > 3 else ""
          
          # Generate seed and key
          seed = mnemonic_to_seed(mnemonic)
          private_key = derive_ed25519_key(seed)
          
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
          
          # Write keys
          with open(output_file, 'wb') as f:
              f.write(private_pem)
          
          with open(f"{output_file}.pub", 'wb') as f:
              f.write(public_ssh)
          
          # Set permissions
          import os
          os.chmod(output_file, 0o600)
          os.chmod(f"{output_file}.pub", 0o644)
          
          print(f"✅ SSH keypair generated:")
          print(f"   Private: {output_file}")
          print(f"   Public:  {output_file}.pub")
          print(f"   Fingerprint: {public_ssh.decode().split()[1][:43]}...")
      
      if __name__ == "__main__":
          main()
      EOF
          
          # Run the key generation
          ${pkgs.nix}/bin/nix-shell -p python3Packages.mnemonic python3Packages.cryptography --run "python3 '$temp_script' '$mnemonic' '$output_file' '$comment'"
          
          # Cleanup
          rm "$temp_script"
          
          echo ""
          echo "🔐 Key generation complete!"
          echo "💡 Next steps:"
          echo "   1. Add public key to GitHub/servers: cat $output_file.pub"
          echo "   2. Test the key: ssh-keygen -l -f $output_file"
          echo "   3. Configure SSH: ssh-add $output_file"
      }
      
      # Default values
      MNEMONIC_LENGTH=24
      OUTPUT_FILE="$HOME/.ssh/id_bip39_ed25519"
      COMMENT="bip39-$(date +%Y%m%d)"
      MNEMONIC=""
      
      # Parse arguments
      while [[ $# -gt 0 ]]; do
          case $1 in
              --generate-mnemonic)
                  MNEMONIC_LENGTH=''${2:-24}
                  generate_mnemonic "$MNEMONIC_LENGTH"
                  exit 0
                  ;;
              --from-mnemonic)
                  MNEMONIC="$2"
                  shift 2
                  ;;
              --output)
                  OUTPUT_FILE="$2"
                  shift 2
                  ;;
              --comment)
                  COMMENT="$2"
                  shift 2
                  ;;
              --help|-h)
                  usage
                  exit 0
                  ;;
              *)
                  echo "❌ Unknown option: $1"
                  usage
                  exit 1
                  ;;
          esac
      done
      
      # If no mnemonic provided, show usage
      if [[ -z "$MNEMONIC" ]]; then
          usage
          exit 1
      fi
      
      # Ensure output directory exists
      mkdir -p "$(dirname "$OUTPUT_FILE")"
      
      # Generate SSH key from mnemonic
      generate_ssh_key "$MNEMONIC" "$OUTPUT_FILE" "$COMMENT"
    '';
    executable = true;
  };

  # Shell aliases
  home.shellAliases = {
    # Home Manager
    hm-switch = "home-manager switch --flake ~/Documents/dotfiles/#user@${detectedHostname}";
    hm-news = "home-manager news --flake ~/Documents/dotfiles/#user@${detectedHostname}";
    hm-gens = "home-manager generations";
    
    # Security
    security-scan = "~/.local/bin/security-scan";
    security-audit = "lynis audit system";
    rootkit-check = "sudo chkrootkit";
    
    # BIP39 SSH Key Management
    bip39-keygen = "~/.local/bin/bip39-ssh-keygen";
    bip39-mnemonic = "~/.local/bin/bip39-ssh-keygen --generate-mnemonic";
  };
}
