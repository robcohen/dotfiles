#!/run/current-system/sw/bin/bash

set -e

HOSTNAME=$(hostname)
FLAKE_DIR=~/Documents/dotfiles

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --no-update    Skip flake update, just rebuild"
    echo "  --quick        Only update nixpkgs (faster)"
    echo "  --input NAME   Update specific input only"
    echo "  -h, --help     Show this help"
}

UPDATE_MODE="full"
SPECIFIC_INPUT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-update)
            UPDATE_MODE="none"
            shift
            ;;
        --quick)
            UPDATE_MODE="quick"
            shift
            ;;
        --input)
            UPDATE_MODE="specific"
            SPECIFIC_INPUT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

echo "🔐 This script requires sudo access for NixOS rebuild..."
sudo -v

case $UPDATE_MODE in
    full)
        echo "🔄 Updating all flake inputs..."
        nix flake update --flake "$FLAKE_DIR"
        ;;
    quick)
        echo "🔄 Quick update (nixpkgs only)..."
        nix flake update stable-nixpkgs unstable-nixpkgs --flake "$FLAKE_DIR"
        ;;
    specific)
        echo "🔄 Updating input: $SPECIFIC_INPUT..."
        nix flake update "$SPECIFIC_INPUT" --flake "$FLAKE_DIR"
        ;;
    none)
        echo "⏭️  Skipping flake update..."
        ;;
esac

echo "🛠  Rebuilding NixOS..."
sudo nixos-rebuild switch --flake "$FLAKE_DIR#$HOSTNAME"

echo "✅ System update complete!"
