# Common swap configuration with automatic file creation
{ config, lib, pkgs, ... }:

let
  cfg = config.swapDevices;
  hasSwapFile = lib.any (swap: lib.hasPrefix "/swap/" swap.device) cfg;
in
{
  config = lib.mkIf hasSwapFile {
    # Ensure swap file exists before activation
    system.activationScripts.ensureSwapFile = lib.stringAfter [ "specialfs" ] ''
      set -euo pipefail
      # Process each swap device
      ${lib.concatMapStrings (swap:
        if lib.hasPrefix "/swap/" swap.device then ''
          SWAP_FILE="${swap.device}"
          SWAP_SIZE_MB=${toString swap.size}

          if [ ! -f "$SWAP_FILE" ]; then
            echo ""
            echo "Setting up swap file..."
            echo "----------------------------------------"

            # Create swap directory
            mkdir -p "$(dirname "$SWAP_FILE")"

            # Create swap file with proper size
            echo "Creating ''${SWAP_SIZE_MB}MB swap file at $SWAP_FILE..."
            dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$SWAP_SIZE_MB status=progress

            # Set proper permissions
            chmod 600 "$SWAP_FILE"

            # Format as swap
            mkswap "$SWAP_FILE"

            echo "Swap file created successfully at $SWAP_FILE"
            echo "----------------------------------------"
            echo ""
          fi
        '' else ""
      ) cfg}
    '';
  };
}
