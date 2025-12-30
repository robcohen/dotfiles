# SOPS secrets management module
{ config, lib, pkgs, ... }:

let
  cfg = config.dotfiles.sops;
  # Get the primary user's home directory, with fallback
  userHome = config.users.users.${cfg.username}.home or "/home/${cfg.username}";

  # Helper for standard root-owned secrets
  mkRootSecret = extra: {
    owner = "root";
    group = "root";
    mode = "0400";
  } // extra;
in
{
  options.dotfiles.sops = {
    username = lib.mkOption {
      type = lib.types.str;
      default = "user";
      description = "Username for secrets file location";
    };

    secretsPath = lib.mkOption {
      type = lib.types.str;
      default = "${userHome}/.secrets/secrets.yaml";
      description = "Path to the SOPS secrets file";
    };
  };

  config = {
    # SOPS configuration
    sops = {
      defaultSopsFile = cfg.secretsPath;
      defaultSopsFormat = "yaml";
      # Allow building before secrets are decrypted/exist
      # In production, set to true and ensure SOPS files exist before building
      validateSopsFiles = false;

      # Age configuration - let SOPS-nix manage the key
      age = {
        generateKey = true;
        keyFile = "/var/lib/sops-nix/key.txt";
      };

      # Define secrets that should be available to the system
      secrets = {
        # User configuration secrets
        "user/name" = mkRootSecret {};
        "user/email" = mkRootSecret {};
        "user/realName" = mkRootSecret {};
        "user/githubUsername" = mkRootSecret {};

        # Domain configuration secrets
        "domains/primary" = mkRootSecret {};
        "domains/vpn" = mkRootSecret {};
        "domains/internal" = mkRootSecret {};

        # User password for userborn compatibility
        "user/hashedPassword" = mkRootSecret { neededForUsers = true; };
      };
    };

    # Helper tools for secrets management
    environment.systemPackages = [
      pkgs.sops
      pkgs.age
      pkgs.tpm2-tools   # TPM management for BIP39 unified keys
      pkgs.openssl      # For HKDF key derivation
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
      set -euo pipefail
      SECRETS_FILE="${cfg.secretsPath}"
      SECRETS_USER="${cfg.username}"
      if [ ! -f "$SECRETS_FILE" ]; then
        echo ""
        echo "WARNING: SOPS secrets file not found!"
        echo "----------------------------------------"
        echo "The file $SECRETS_FILE is required for SOPS."
        echo ""
        echo "Creating a placeholder file now. Run these commands:"
        echo ""
        echo "  mkdir -p ~/.secrets"
        echo "  echo '{}' > ~/.secrets/secrets.yaml"
        echo ""
        echo "Then configure your secrets with sops later."
        echo "----------------------------------------"

        # Create the directory and placeholder file
        mkdir -p "$(dirname "$SECRETS_FILE")"
        echo '{}' > "$SECRETS_FILE"
        chown "$SECRETS_USER:users" "$SECRETS_FILE"
        chmod 600 "$SECRETS_FILE"

        echo "Created placeholder secrets file at $SECRETS_FILE"
        echo ""
      fi
    '';
  };
}
