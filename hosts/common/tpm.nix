{ pkgs, lib, config, ... }:

{
  # TPM 2.0 support
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };

  # TPM hardware packages (system-level)
  environment.systemPackages = with pkgs; [
    tpm2-tools
    tpm2-tss
    tpm2-pkcs11
    age-plugin-tpm
  ];

  # TPM initialization script (system-level)
  environment.etc."scripts/tpm-init" = {
    text = ''
      #!${pkgs.bash}/bin/bash
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
      
      # Suppress tabrmd warnings by using direct device access
      export TPM2TOOLS_TCTI="device:/dev/tpmrm0"
      
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
      
      # Suppress tabrmd warnings by using direct device access
      export TPM2TOOLS_TCTI="device:/dev/tpmrm0"
      
      # Create primary key in owner hierarchy with proper attributes for being a parent
      tpm2_createprimary -C o -g sha256 -G ecc256 -c /tmp/primary.ctx \
          -a "fixedtpm|fixedparent|sensitivedataorigin|userwithauth|restricted|decrypt" 2>/dev/null
      
      # Make it persistent at handle 0x81000001  
      tpm2_evictcontrol -C o -c /tmp/primary.ctx 0x81000001 2>/dev/null
      
      # Clean up
      rm -f /tmp/primary.ctx
      
      echo "✅ TPM initialized successfully"
      echo "   Primary key handle: 0x81000001"
      echo "   Ready for SSH key storage"
    '';
    mode = "0755";
  };

  # System-level TPM key management utilities
  environment.etc."scripts/tpm-keys" = {
    text = ''
      #!${pkgs.bash}/bin/bash
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
          echo "  remove <handle>    Remove handle from TPM (DESTRUCTIVE)"
          echo ""
          echo "Options:"
          echo "  --help             Show this help"
          echo ""
          echo "Examples:"
          echo "  $0 list"
          echo "  $0 info 0x81000100"
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
                  echo "💡 Use: tpm-init to initialize TPM"
                  exit 0
              fi
              
              printf "%-12s %-10s\\n" "Handle" "Status"
              printf "%-12s %-10s\\n" "--------" "--------"
              
              for handle in $HANDLES; do
                  if tpm2_readpublic -c "$handle" >/dev/null 2>&1; then
                      printf "%-12s %-10s\\n" "$handle" "active"
                  else
                      printf "%-12s %-10s\\n" "$handle" "error"
                  fi
              done
              ;;
              
          "info")
              if [[ $# -lt 2 ]]; then
                  echo "❌ Missing handle argument" >&2
                  echo "💡 Use: $0 info 0x81000100" >&2
                  exit 1
              fi
              
              HANDLE="$2"
              
              # Check if handle exists
              if ! tpm2_readpublic -c "$HANDLE" >/dev/null 2>&1; then
                  echo "❌ Handle $HANDLE not found in TPM" >&2
                  exit 1
              fi
              
              echo "🔍 TPM Handle Information: $HANDLE"
              echo ""
              tpm2_readpublic -c "$HANDLE"
              ;;
              
          "remove")
              if [[ $# -lt 2 ]]; then
                  echo "❌ Missing handle argument" >&2
                  echo "💡 Use: $0 remove 0x81000100" >&2
                  exit 1
              fi
              
              HANDLE="$2"
              
              # Check if handle exists
              if ! tpm2_readpublic -c "$HANDLE" >/dev/null 2>&1; then
                  echo "❌ Handle $HANDLE not found in TPM" >&2
                  exit 1
              fi
              
              echo "⚠️  WARNING: About to permanently remove TPM key!"
              echo "   Handle: $HANDLE"
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
              ;;
              
          *)
              echo "❌ Unknown command: $COMMAND" >&2
              echo "💡 Available commands: list, info, remove" >&2
              echo "💡 Use: $0 --help for more information" >&2
              exit 1
              ;;
      esac
    '';
    mode = "0755";
  };

  # TPM udev rules for proper permissions
  services.udev.extraRules = ''
    # TPM device access
    SUBSYSTEM=="tpm", GROUP="tss", MODE="0660"
    SUBSYSTEM=="tpmrm", GROUP="tss", MODE="0660"
  '';

  # Ensure TPM group exists
  users.groups.tss = {};

  # Create symlinks for system TPM utilities
  system.activationScripts.tpm-utilities = ''
    mkdir -p /usr/local/bin
    ln -sf /etc/scripts/tpm-init /usr/local/bin/tpm-init
    ln -sf /etc/scripts/tpm-keys /usr/local/bin/tpm-keys
  '';
}