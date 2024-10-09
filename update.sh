#!/run/current-system/sw/bin/bash

# Get the current user
CURRENT_USER=$(whoami)

# Get the hostname
HOSTNAME=$(hostname)

# Run the commands
echo "Updating Nix flake..."
nix flake update

echo "Rebuilding NixOS..."
sudo nixos-rebuild switch --flake ~/Documents/dotfiles/#$HOSTNAME

echo "Switching Home Manager configuration..."
home-manager switch --flake ~/Documents/dotfiles/#$CURRENT_USER@$HOSTNAME

echo "Update complete!"
