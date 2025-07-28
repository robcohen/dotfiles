#!/run/current-system/sw/bin/bash

set -e

PINNED_NIXOS=$(grep '^\s*stable-nixpkgs\.url' flake.nix | sed -E 's/.*nixos-([0-9]+\.[0-9]+).*/\1/')
PINNED_HM=$(grep 'home-manager.url' flake.nix | sed -E 's/.*release-([0-9]+\.[0-9]+).*/\1/')

echo "🔍 Checking latest NixOS and Home Manager stable releases…"

LATEST_NIXOS=$(git ls-remote --heads https://github.com/NixOS/nixpkgs \
  | grep -o 'refs/heads/nixos-[0-9]\{2\}\.[0-9]\{2\}' \
  | sed 's|refs/heads/nixos-||' \
  | sort -V \
  | tail -n1)

LATEST_HM=$(git ls-remote --heads https://github.com/nix-community/home-manager \
  | grep -o 'refs/heads/release-[0-9]\{2\}\.[0-9]\{2\}' \
  | sed 's|refs/heads/release-||' \
  | sort -V \
  | tail -n1)

echo ""
echo "Pinned nixpkgs:       nixos-$PINNED_NIXOS"
echo "Latest nixpkgs branch: nixos-${LATEST_NIXOS:-<none>}"
echo "Pinned home-manager:  release-$PINNED_HM"
echo "Latest HM branch:     release-${LATEST_HM:-<none>}"
echo ""

if [[ -z "$LATEST_NIXOS" || -z "$LATEST_HM" ]]; then
  echo "❌ Could not fetch latest release info. Check network or GitHub access."
  exit 1
fi

if [[ "$PINNED_NIXOS" != "$LATEST_NIXOS" || "$PINNED_HM" != "$LATEST_HM" ]]; then
  echo "🚨 New upstream release(s) detected!"
  echo "Update your flake.nix before running system update."
  exit 1
fi

echo "✅ No upstream release changes detected."
