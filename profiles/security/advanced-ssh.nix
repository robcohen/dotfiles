{ config, pkgs, lib, hostType, ... }:

{
  programs.ssh = {
    # Enhanced SSH security configuration
    extraConfig = ''
      # Additional security hardening
      HashKnownHosts yes
      VisualHostKey yes
      StrictHostKeyChecking ask
      VerifyHostKeyDNS yes
      
      # Note: ForwardAgent needed for SSH signing, so only disable for remote hosts
      ForwardX11 no
      ForwardX11Trusted no
      PermitLocalCommand no
      
      # TPM2-PKCS11 support for hardware-backed keys (disabled to avoid RSA key conflict)
      # PKCS11Provider ${pkgs.tpm2-pkcs11}/lib/libtpm2_pkcs11.so
      
      # Connection security
      HostbasedAuthentication no
      PubkeyAuthentication yes
      ChallengeResponseAuthentication no
      
      # Modern key exchange
      PubkeyAcceptedKeyTypes ssh-ed25519,rsa-sha2-512,rsa-sha2-256
      HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256
      
      # Prevent connection attacks
      IPQoS throughput
      UpdateHostKeys ask
      
      # Security-focused connection timeouts
      ConnectTimeout 30
      BatchMode no
      CheckHostIP yes
    '';
    
    # Host-specific security configurations
    matchBlocks = {
      "localhost" = {
        # Allow agent for local git signing
        extraOptions = {
          ForwardAgent = "yes";
        };
      };
      
      "*.internal" = {
        # Internal network hosts
        user = "user";
        identityFile = "~/.ssh/id_ed25519";
        extraOptions = {
          StrictHostKeyChecking = "yes";
          VerifyHostKeyDNS = "no";  # Internal DNS may not have SSH fingerprints
        };
      };
      
      "github.com" = {
        # GitHub-specific security
        user = "git";
        identityFile = "~/.ssh/id_bip39_ed25519";
        extraOptions = {
          StrictHostKeyChecking = "yes";
          VerifyHostKeyDNS = "yes";
          ForwardAgent = "no";  # Disable for remote connections
          IdentitiesOnly = "yes";  # Force only the specified identity file
        };
      };
      
      "*" = {
        # Default settings for all other hosts
        extraOptions = {
          ForwardAgent = "no";  # Disable by default for security
        };
      };
      
      "*.onion" = {
        # Tor hidden services
        extraOptions = {
          ProxyCommand = "${pkgs.tor}/bin/torify ${pkgs.netcat}/bin/nc %h %p";
          CheckHostIP = "no";
          Compression = "yes";
        };
      };
    };
  };

  # SSH security monitoring and tools
  home.packages = with pkgs; [
    ssh-audit       # SSH server security scanner
    sshfs           # Secure filesystem over SSH
    mosh            # Mobile shell for unreliable connections  
    assh            # Advanced SSH config manager
  ];

  # SSH key management scripts
  home.file.".local/bin/ssh-audit-local" = {
    text = ''
      #!/bin/bash
      # SSH client security audit
      set -euo pipefail
      
      echo "🔍 SSH Client Security Audit"
      echo "============================"
      
      echo "📋 SSH Version:"
      ssh -V 2>&1
      
      echo ""
      echo "🔑 Available Keys:"
      for keyfile in ~/.ssh/id_*; do
        if [[ -f "$keyfile" && ! "$keyfile" =~ \.pub$ ]]; then
          echo "$(basename "$keyfile"):"
          ssh-keygen -l -f "$keyfile" 2>/dev/null || echo "  Invalid or encrypted key"
        fi
      done
      
      echo ""
      echo "🛡️ SSH Agent Status:"
      if ssh-add -l >/dev/null 2>&1; then
        echo "SSH agent is running with loaded keys:"
        ssh-add -l
      else
        echo "SSH agent not running or no keys loaded"
      fi
      
      echo ""
      echo "📊 Known Hosts:"
      if [[ -f ~/.ssh/known_hosts ]]; then
        echo "Known hosts entries: $(wc -l < ~/.ssh/known_hosts)"
        echo "Hashed entries: $(grep -c "^|" ~/.ssh/known_hosts || echo 0)"
      else
        echo "No known_hosts file found"
      fi
      
      echo ""
      echo "⚙️ Configuration Test:"
      ssh -G localhost | grep -E "^(ciphers|macs|kexalgorithms|hostkeyalgorithms)"
      
      echo ""
      echo "🔒 Security Recommendations:"
      echo "- Use Ed25519 keys for new hosts"
      echo "- Enable hardware security key support"
      echo "- Regularly audit authorized_keys"
      echo "- Use SSH certificates for large deployments"
    '';
    executable = true;
  };

  # SSH key rotation helper
  home.file.".local/bin/ssh-rotate-keys" = {
    text = ''
      #!/bin/bash
      # SSH key rotation helper
      set -euo pipefail
      
      echo "🔄 SSH Key Rotation Helper"
      echo "========================="
      
      read -p "Generate new Ed25519 key? [y/N]: " -n 1 -r
      echo ""
      
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        KEYNAME="id_ed25519_$(date +%Y%m%d)"
        
        echo "Generating new key: $KEYNAME"
        ssh-keygen -t ed25519 -f ~/.ssh/"$KEYNAME" -C "$(whoami)@$(hostname)-$(date +%Y%m%d)"
        
        echo "New public key:"
        cat ~/.ssh/"$KEYNAME.pub"
        
        echo ""
        echo "Next steps:"
        echo "1. Add public key to your servers/services"
        echo "2. Test the new key"
        echo "3. Update SSH config to use new key"
        echo "4. Remove old key from authorized_keys"
        echo "5. Delete old private key securely"
      fi
    '';
    executable = true;
  };

  # Secure file transfer wrapper
  home.file.".local/bin/secure-scp" = {
    text = ''
      #!/bin/bash
      # Secure SCP wrapper with integrity checking
      set -euo pipefail
      
      if [[ $# -lt 2 ]]; then
        echo "Usage: secure-scp <source> <destination>"
        echo "Secure file transfer with integrity verification"
        exit 1
      fi
      
      SOURCE="$1"
      DEST="$2"
      
      # Generate checksum
      if [[ -f "$SOURCE" ]]; then
        CHECKSUM=$(sha256sum "$SOURCE" | cut -d' ' -f1)
        echo "Source SHA256: $CHECKSUM"
        
        # Transfer file
        scp -o Compression=yes -o Cipher=chacha20-poly1305@openssh.com "$SOURCE" "$DEST"
        
        # Verify on remote (if remote destination)
        if [[ "$DEST" =~ : ]]; then
          REMOTE_HOST=$(echo "$DEST" | cut -d: -f1)
          REMOTE_PATH=$(echo "$DEST" | cut -d: -f2)
          
          echo "Verifying remote file integrity..."
          REMOTE_CHECKSUM=$(ssh "$REMOTE_HOST" "sha256sum '$REMOTE_PATH'" | cut -d' ' -f1)
          
          if [[ "$CHECKSUM" == "$REMOTE_CHECKSUM" ]]; then
            echo "✅ File integrity verified"
          else
            echo "❌ File integrity check failed!"
            exit 1
          fi
        fi
      else
        echo "Source file not found: $SOURCE"
        exit 1
      fi
    '';
    executable = true;
  };
}