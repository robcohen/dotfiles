# SOPS secrets management module
{ config, lib, pkgs, ... }:

with lib;

{
  # SOPS configuration
  sops = {
    defaultSopsFile = "/home/user/.secrets/secrets.yaml";
    defaultSopsFormat = "yaml";
    validateSopsFiles = false;  # Allow building before secrets file exists

    # Age configuration - let SOPS-nix manage the key
    age = {
      generateKey = true;
      keyFile = "/var/lib/sops-nix/key.txt";
    };

    # Define secrets that should be available to the system
    secrets = {
      # User configuration secrets
      "user/name" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "user/email" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "user/realName" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "user/githubUsername" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };

      # Domain configuration secrets
      "domains/primary" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "domains/vpn" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "domains/internal" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };
  };

  # Helper functions to read secrets
  environment.systemPackages = with pkgs; [
    sops
    age
    tpm2-tools      # TPM management for BIP39 unified keys
    openssl         # For HKDF key derivation
  ];

  # Ensure SOPS service is running
  systemd.services.sops-nix = {
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  # Pre-activation check for secrets file
  system.activationScripts.ensureSecretsFile = lib.stringAfter [ "users" ] ''
    SECRETS_FILE="/home/user/.secrets/secrets.yaml"
    if [ ! -f "$SECRETS_FILE" ]; then
      echo ""
      echo "⚠️  WARNING: SOPS secrets file not found!"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "The file $SECRETS_FILE is required for SOPS."
      echo ""
      echo "Creating a placeholder file now. Run these commands:"
      echo ""
      echo "  mkdir -p ~/.secrets"
      echo "  echo '{}' > ~/.secrets/secrets.yaml"
      echo ""
      echo "Then configure your secrets with sops later."
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      
      # Create the directory and placeholder file
      mkdir -p "$(dirname "$SECRETS_FILE")"
      echo '{}' > "$SECRETS_FILE"
      chown user:users "$SECRETS_FILE"
      chmod 600 "$SECRETS_FILE"
      
      echo "✓ Created placeholder secrets file at $SECRETS_FILE"
      echo ""
    fi
  '';
}
