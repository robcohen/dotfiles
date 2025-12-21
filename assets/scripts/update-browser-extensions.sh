#!/run/current-system/sw/bin/bash
#
# Update browser extension versions in nix config
# Called by full-update.sh or manually
#

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/Documents/dotfiles}"
CHROMIUM_NIX="$DOTFILES/profiles/programs/ungoogled-chromium.nix"

# Extension definitions
# Format: name|type|source|nix_var
# Types: github (repo|asset_pattern), chrome (extension_id)
EXTENSIONS=(
  "Chromium Web Store|github|NeverDecaf/chromium-web-store|Chromium.Web.Store.crx|chromium-web-store"
  "Bitwarden|github-zip|bitwarden/clients|dist-chrome|bitwarden"
)

get_current_version() {
  local nix_var="$1"
  grep -A5 "$nix_var = " "$CHROMIUM_NIX" | grep 'version = ' | head -1 | sed -E 's/.*version = "([^"]+)".*/\1/' || echo ""
}

get_current_hash() {
  local nix_var="$1"
  grep -A10 "$nix_var = " "$CHROMIUM_NIX" | grep 'sha256 = ' | head -1 | sed -E 's/.*sha256 = "([^"]+)".*/\1/' || echo ""
}

update_nix_file() {
  local nix_var="$1"
  local old_version="$2"
  local new_version="$3"
  local old_hash="$4"
  local new_hash="$5"

  # Update version
  sed -i "s|$nix_var = .*{|$nix_var = {|" "$CHROMIUM_NIX"  # Normalize

  # For fetchChromeExtension style
  sed -i "/$nix_var = /,/};/s|version = \"$old_version\"|version = \"$new_version\"|" "$CHROMIUM_NIX"
  sed -i "/$nix_var = /,/};/s|sha256 = \"$old_hash\"|sha256 = \"$new_hash\"|" "$CHROMIUM_NIX"

  # For GitHub style (version in URL)
  sed -i "s|/v$old_version/|/v$new_version/|g" "$CHROMIUM_NIX"
  sed -i "s|/$old_version/|/$new_version/|g" "$CHROMIUM_NIX"
}

check_github_extension() {
  local name="$1"
  local repo="$2"
  local asset_pattern="$3"
  local nix_var="$4"

  echo "Checking $name..."

  local release_info
  release_info=$(curl -sf "https://api.github.com/repos/$repo/releases/latest") || {
    echo "  Failed to fetch release info"
    return 1
  }

  local latest_version
  latest_version=$(echo "$release_info" | jq -r '.tag_name' | sed 's/^v//')

  local current_version
  current_version=$(get_current_version "$nix_var")

  echo "  Current: $current_version"
  echo "  Latest:  $latest_version"

  if [[ "$current_version" == "$latest_version" ]]; then
    echo "  Up to date"
    return 0
  fi

  echo "  Update available!"

  local download_url
  download_url=$(echo "$release_info" | jq -r ".assets[] | select(.name == \"$asset_pattern\") | .browser_download_url")

  if [[ -z "$download_url" ]]; then
    echo "  Could not find asset: $asset_pattern"
    return 1
  fi

  echo "  Fetching new hash..."
  local new_hash
  new_hash=$(nix-prefetch-url --type sha256 "$download_url" 2>/dev/null) || {
    echo "  Failed to prefetch"
    return 1
  }

  local old_hash
  old_hash=$(get_current_hash "$nix_var")

  update_nix_file "$nix_var" "$current_version" "$latest_version" "$old_hash" "$new_hash"

  echo "  Updated: $current_version -> $latest_version"
  return 2
}

check_github_zip_extension() {
  local name="$1"
  local repo="$2"
  local asset_prefix="$3"
  local nix_var="$4"

  echo "Checking $name..."

  local release_info
  release_info=$(curl -sf "https://api.github.com/repos/$repo/releases/latest") || {
    echo "  Failed to fetch release info"
    return 1
  }

  # Extract version from tag (e.g., "browser-v2025.12.0" -> "2025.12.0")
  local tag_name latest_version
  tag_name=$(echo "$release_info" | jq -r '.tag_name')
  latest_version=$(echo "$tag_name" | sed -E 's/.*-v([0-9]+\.[0-9]+\.[0-9]+).*/\1/')

  local current_version
  current_version=$(get_current_version "$nix_var")

  echo "  Current: $current_version"
  echo "  Latest:  $latest_version"

  if [[ "$current_version" == "$latest_version" ]]; then
    echo "  Up to date"
    return 0
  fi

  echo "  Update available!"

  # Find the matching asset
  local asset_name download_url
  asset_name=$(echo "$release_info" | jq -r ".assets[].name" | grep "^${asset_prefix}-${latest_version}\.zip$" | head -1)

  if [[ -z "$asset_name" ]]; then
    # Try alternate pattern
    asset_name=$(echo "$release_info" | jq -r ".assets[].name" | grep "^${asset_prefix}.*${latest_version}.*\.zip$" | head -1)
  fi

  if [[ -z "$asset_name" ]]; then
    echo "  Could not find asset matching: ${asset_prefix}-${latest_version}.zip"
    return 1
  fi

  download_url=$(echo "$release_info" | jq -r ".assets[] | select(.name == \"$asset_name\") | .browser_download_url")

  echo "  Fetching new hash for $asset_name..."
  local new_hash
  new_hash=$(nix-prefetch-url --unpack --type sha256 "$download_url" 2>/dev/null) || {
    echo "  Failed to prefetch"
    return 1
  }
  # Convert to SRI format
  new_hash="sha256-$(nix hash convert --hash-algo sha256 --to sri "$new_hash" 2>/dev/null | cut -d- -f2)"

  local old_hash
  old_hash=$(get_current_hash "$nix_var")

  # Update version
  sed -i "/$nix_var = /,/};/s|version = \"$current_version\"|version = \"$latest_version\"|" "$CHROMIUM_NIX"

  # Update URL (version appears in URL)
  sed -i "s|browser-v$current_version|browser-v$latest_version|g" "$CHROMIUM_NIX"
  sed -i "s|${asset_prefix}-$current_version|${asset_prefix}-$latest_version|g" "$CHROMIUM_NIX"

  # Update hash
  sed -i "s|$old_hash|$new_hash|g" "$CHROMIUM_NIX"

  echo "  Updated: $current_version -> $latest_version"
  return 2
}

check_chrome_extension() {
  local name="$1"
  local ext_id="$2"
  local nix_var="$3"

  echo "Checking $name..."

  local current_version
  current_version=$(get_current_version "$nix_var")

  if [[ -z "$current_version" ]]; then
    echo "  Could not find current version"
    return 1
  fi

  # Fetch the crx to get latest version
  local crx_url="https://clients2.google.com/service/update2/crx?response=redirect&prodversion=120&acceptformat=crx2,crx3&x=id%3D${ext_id}%26installsource%3Dondemand%26uc"

  local tmpfile
  tmpfile=$(mktemp)

  if ! curl -sfL -o "$tmpfile" "$crx_url"; then
    echo "  Failed to download extension"
    rm -f "$tmpfile"
    return 1
  fi

  local latest_version manifest_json
  manifest_json=$(unzip -p "$tmpfile" manifest.json 2>/dev/null) || true
  latest_version=$(echo "$manifest_json" | jq -r '.version' 2>/dev/null)
  if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
    echo "  Failed to extract version"
    rm -f "$tmpfile"
    return 1
  fi

  echo "  Current: $current_version"
  echo "  Latest:  $latest_version"

  if [[ "$current_version" == "$latest_version" ]]; then
    echo "  Up to date"
    rm -f "$tmpfile"
    return 0
  fi

  echo "  Update available!"

  # Get hash using nix-prefetch-url
  echo "  Fetching new hash..."
  local new_hash
  new_hash=$(nix-prefetch-url --name "${ext_id}.crx" --type sha256 "$crx_url" 2>/dev/null) || {
    echo "  Failed to get hash"
    rm -f "$tmpfile"
    return 1
  }

  local old_hash
  old_hash=$(get_current_hash "$nix_var")

  update_nix_file "$nix_var" "$current_version" "$latest_version" "$old_hash" "$new_hash"

  rm -f "$tmpfile"
  echo "  Updated: $current_version -> $latest_version"
  return 2
}

main() {
  local updates_made=0

  echo "Checking browser extensions for updates..."
  echo ""

  for ext in "${EXTENSIONS[@]}"; do
    IFS='|' read -ra parts <<< "$ext"
    local name="${parts[0]}"
    local ext_type="${parts[1]}"

    local result=0
    if [[ "$ext_type" == "github" ]]; then
      local repo="${parts[2]}"
      local asset="${parts[3]}"
      local nix_var="${parts[4]}"
      check_github_extension "$name" "$repo" "$asset" "$nix_var" || result=$?
    elif [[ "$ext_type" == "github-zip" ]]; then
      local repo="${parts[2]}"
      local asset_prefix="${parts[3]}"
      local nix_var="${parts[4]}"
      check_github_zip_extension "$name" "$repo" "$asset_prefix" "$nix_var" || result=$?
    elif [[ "$ext_type" == "chrome" ]]; then
      local ext_id="${parts[2]}"
      local nix_var="${parts[3]}"
      check_chrome_extension "$name" "$ext_id" "$nix_var" || result=$?
    fi

    if [[ $result -eq 2 ]]; then
      ((updates_made++))
    fi
    echo ""
  done

  if [[ $updates_made -gt 0 ]]; then
    echo "Updated $updates_made extension(s). Changes will apply on next home-manager switch."
  else
    echo "All extensions up to date."
  fi
}

main "$@"
