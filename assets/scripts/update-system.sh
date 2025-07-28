#!/run/current-system/sw/bin/bash

set -e

HOSTNAME=$(hostname)

echo "🔐 This script requires sudo access for NixOS rebuild..."
sudo -v

echo "🔄 Updating Nix flake..."
nix flake update

echo "🛠  Rebuilding NixOS..."
sudo nixos-rebuild switch --flake ~/Documents/dotfiles/#$HOSTNAME

echo "✅ System update complete!"
