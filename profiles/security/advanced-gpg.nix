{ config, pkgs, lib, hostType, ... }:

{
  programs.gpg = {
    # Enhanced GPG security settings beyond the basic config
    settings = {
      # Enhanced security options
      auto-key-retrieve = false;  # Don't auto-retrieve keys
      auto-key-locate = false;    # Don't auto-locate keys
      keyserver-options = "no-honor-keyserver-url no-honor-pka-record";
      
      # Trust model hardening
      trust-model = "tofu+pgp";  # Trust on first use + PGP web of trust
      tofu-default-policy = "ask";
      
      # Photo display security
      no-show-photos = true;
      
      # Prevent information leakage
      export-options = "export-minimal";
      import-options = "import-minimal";
      
      # Key preferences for new keys
      default-new-key-algo = "ed25519/cert,sign+cv25519/encr";
      
      # Compliance mode for government/enterprise
      compliance = "gnupg";
      
      # Memory protection
      require-secmem = true;
    };
    
    # Secure keyserver configuration
    scdaemonSettings = {
      disable-ccid = false;
      pcsc-driver = "${pkgs.pcsclite}/lib/libpcsclite.so.1";
    };
  };

  # GPG-related security tools
  home.packages = with pkgs; [
    paperkey        # Backup GPG keys to paper
    qrencode        # Generate QR codes for key sharing
    tomb            # Encrypted storage
    age             # Modern encryption tool
    rage            # Rust implementation of age
  ];

  # Secure GPG backup scripts
  home.file.".local/bin/gpg-backup" = {
    text = ''
      #!/bin/bash
      # Secure GPG key backup script
      set -euo pipefail
      
      BACKUP_DIR="$HOME/.gnupg/backup"
      DATE=$(date +%Y%m%d)
      
      echo "🔐 Creating secure GPG backup..."
      
      # Create backup directory
      mkdir -p "$BACKUP_DIR"
      chmod 700 "$BACKUP_DIR"
      
      # Export public keys
      gpg --armor --export > "$BACKUP_DIR/public-keys-$DATE.asc"
      
      # Export secret keys (encrypted)
      gpg --armor --export-secret-keys > "$BACKUP_DIR/secret-keys-$DATE.asc.gpg"
      
      # Export ownertrust
      gpg --export-ownertrust > "$BACKUP_DIR/ownertrust-$DATE.txt"
      
      # Create paper backup
      paperkey --secret-key "$BACKUP_DIR/secret-keys-$DATE.asc.gpg" \
               --output "$BACKUP_DIR/paperkey-$DATE.txt"
      
      echo "✅ Backup created in $BACKUP_DIR"
      echo "📄 Paper backup: paperkey-$DATE.txt"
      echo "🔒 Store paper backup in secure location!"
    '';
    executable = true;
  };

  # GPG key verification script
  home.file.".local/bin/gpg-verify" = {
    text = ''
      #!/bin/bash
      # GPG key security verification
      set -euo pipefail
      
      echo "🔍 GPG Security Audit"
      echo "===================="
      
      echo "📋 GPG Version:"
      gpg --version | head -1
      
      echo ""
      echo "🔑 Key Information:"
      gpg --list-secret-keys --keyid-format long
      
      echo ""
      echo "🔒 Key Capabilities Check:"
      for keyid in $(gpg --list-secret-keys --with-colons | awk -F: '/^sec:/ { print $5 }'); do
        echo "Key $keyid:"
        gpg --edit-key $keyid check quit 2>/dev/null || echo "  Warning: Key check failed"
      done
      
      echo ""
      echo "⚙️ GPG Agent Status:"
      gpg-connect-agent 'keyinfo --list' /bye | grep -E '^S KEYINFO'
      
      echo ""
      echo "🛡️ Security Recommendations:"
      echo "- Use hardware security keys when possible"
      echo "- Regularly rotate subkeys"
      echo "- Keep master key offline"
      echo "- Verify key fingerprints in person"
    '';
    executable = true;
  };
}