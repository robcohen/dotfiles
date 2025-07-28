#!/run/current-system/sw/bin/bash

set -e

CURRENT_USER=$(whoami)
HOSTNAME=$(hostname)

echo "🏠 Switching Home Manager config..."
if ! command -v home-manager &> /dev/null; then
  echo "  📦 Home Manager not found, bootstrapping..."
  nix run --no-write-lock-file github:nix-community/home-manager/release-25.05 -- switch --flake ~/Documents/dotfiles/#$CURRENT_USER@$HOSTNAME
else
  home-manager switch --flake ~/Documents/dotfiles/#$CURRENT_USER@$HOSTNAME
fi

echo "✅ Home Manager update complete! News:"
home-manager news --flake ~/Documents/dotfiles/#$CURRENT_USER@$HOSTNAME
