#!/usr/bin/env bash
#
# Compare current browser Preferences with what home-manager will write.
# Run before `home-manager switch` to review changes.
#
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/Documents/dotfiles}"

echo "=== Chromium Preferences ==="
CHROMIUM_CURRENT="$HOME/.config/chromium/Default/Preferences"
CHROMIUM_NIX="$DOTFILES/profiles/programs/ungoogled-chromium.nix"

if [[ -f "$CHROMIUM_CURRENT" ]]; then
  # Extract JSON from nix file and compare
  echo "Current vs Declared (showing browser additions/changes):"
  echo ""

  # Pretty-print both and diff
  diff -u \
    <(nix eval --raw -f "$DOTFILES" homeConfigurations.\"user@snix\".config.home.file.\".config/chromium/Default/Preferences\".text 2>/dev/null | jq -S '.' 2>/dev/null || echo "{}") \
    <(jq -S '.' "$CHROMIUM_CURRENT" 2>/dev/null || echo "{}") \
    | head -100 || true

  echo ""
  echo "---"
  echo "If you want to keep browser changes, update ungoogled-chromium.nix"
  echo "Then run: home-manager switch --flake .#user@snix"
else
  echo "No existing Preferences file found"
fi
