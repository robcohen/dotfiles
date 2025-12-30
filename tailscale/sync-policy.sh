#!/usr/bin/env bash
#
# Sync Tailscale policy from local file to tailnet
#
# Prerequisites:
#   1. Create OAuth client at: https://login.tailscale.com/admin/settings/oauth
#      - Scopes needed: acl (read/write)
#   2. Set environment variables:
#      export TS_OAUTH_CLIENT_ID="..."
#      export TS_OAUTH_SECRET="..."
#      export TS_TAILNET="your-tailnet-name"  # or use "-" for default
#
# Usage:
#   ./sync-policy.sh          # Preview changes (dry-run)
#   ./sync-policy.sh --apply  # Apply changes
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
POLICY_FILE="${SCRIPT_DIR}/policy.hujson"

# Source .env file if it exists
if [[ -f "${REPO_ROOT}/.env" ]]; then
  # shellcheck source=/dev/null
  source "${REPO_ROOT}/.env"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check prerequisites
check_env() {
  local missing=0

  # Check required commands
  for cmd in hujsonfmt jq curl; do
    if ! command -v "$cmd" &>/dev/null; then
      echo -e "${RED}Missing required command: ${cmd}${NC}"
      missing=1
    fi
  done

  # Check required env vars
  for var in TS_OAUTH_CLIENT_ID TS_OAUTH_SECRET TS_TAILNET CONTROLD_RESOLVER_ID; do
    if [[ -z "${!var:-}" ]]; then
      echo -e "${RED}Missing required env var: ${var}${NC}"
      missing=1
    fi
  done

  if [[ $missing -eq 1 ]]; then
    echo ""
    echo "Install missing commands: nix shell nixpkgs#hujsonfmt nixpkgs#jq nixpkgs#curl"
    echo ""
    echo "Create OAuth client at: https://login.tailscale.com/admin/settings/oauth"
    echo "Required scope: acl (read/write)"
    echo ""
    echo "Ensure CONTROLD_RESOLVER_ID is set in .env"
    exit 1
  fi
}

# Substitute environment variables in policy file
# Returns path to temp file with substitutions applied
substitute_env_vars() {
  local temp_file
  temp_file=$(mktemp)

  # Substitute ${VAR} patterns with actual values
  sed -e "s|\${CONTROLD_RESOLVER_ID}|${CONTROLD_RESOLVER_ID}|g" \
      "$POLICY_FILE" > "$temp_file"

  echo "$temp_file"
}

# Get OAuth access token
get_token() {
  curl -s -X POST "https://api.tailscale.com/api/v2/oauth/token" \
    -u "${TS_OAUTH_CLIENT_ID}:${TS_OAUTH_SECRET}" \
    -d "grant_type=client_credentials" \
    | jq -r '.access_token'
}

# Get current policy
get_current_policy() {
  local token="$1" # noqa: secret
  curl -s "https://api.tailscale.com/api/v2/tailnet/${TS_TAILNET}/acl" \
    -H "Authorization: Bearer ${token}"
}

# Validate policy (dry-run)
validate_policy() {
  local token="$1" # noqa: secret
  local policy_file="$2"
  echo -e "${YELLOW}Validating policy...${NC}"

  local response
  response=$(curl -s -w "\n%{http_code}" \
    "https://api.tailscale.com/api/v2/tailnet/${TS_TAILNET}/acl/validate" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/hujson" \
    --data-binary "@${policy_file}")

  local http_code
  http_code=$(echo "$response" | tail -1)
  local body
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" ]]; then
    echo -e "${GREEN}Policy is valid${NC}"

    # Show test results if any
    local tests
    tests=$(echo "$body" | jq -r '.message // empty')
    if [[ -n "$tests" ]]; then
      echo "$tests"
    fi
    return 0
  else
    echo -e "${RED}Policy validation failed:${NC}"
    echo "$body" | jq -r '.message // .'
    return 1
  fi
}

# Apply policy
apply_policy() {
  local token="$1" # noqa: secret
  local policy_file="$2"
  echo -e "${YELLOW}Applying policy...${NC}"

  local response
  response=$(curl -s -w "\n%{http_code}" \
    "https://api.tailscale.com/api/v2/tailnet/${TS_TAILNET}/acl" \
    -X POST \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/hujson" \
    --data-binary "@${policy_file}")

  local http_code
  http_code=$(echo "$response" | tail -1)
  local body
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" ]]; then
    echo -e "${GREEN}Policy applied successfully${NC}"
    return 0
  else
    echo -e "${RED}Failed to apply policy:${NC}"
    echo "$body" | jq -r '.message // .'
    return 1
  fi
}

# Convert HuJSON to normalized JSON for comparison
# Uses hujsonfmt (Tailscale's official tool) to strip comments and trailing commas
normalize_json() {
  hujsonfmt -s | jq -S '.'
}

# Show diff between current and new policy
# Returns 0 if there are changes, 1 if no changes
show_diff() {
  local token="$1" # noqa: secret
  local policy_file="$2"

  local current
  current=$(get_current_policy "$token" | normalize_json)
  local new
  new=$(cat "$policy_file" | normalize_json)

  local diff_output
  diff_output=$(diff -u <(echo "$current") <(echo "$new")) || true

  if [[ -z "$diff_output" ]]; then
    echo -e "${GREEN}No changes detected - policy is already in sync${NC}"
    return 1
  else
    echo -e "${YELLOW}Changes to apply:${NC}"
    echo "$diff_output"
    return 0
  fi
}

main() {
  local apply=false
  if [[ "${1:-}" == "--apply" ]]; then
    apply=true
  fi

  check_env

  if [[ ! -f "$POLICY_FILE" ]]; then
    echo -e "${RED}Policy file not found: ${POLICY_FILE}${NC}"
    exit 1
  fi

  echo "Policy file: ${POLICY_FILE}"
  echo "Tailnet: ${TS_TAILNET}"
  echo ""

  # Create temp file with environment variables substituted
  local processed_policy
  processed_policy=$(substitute_env_vars)
  trap "rm -f '$processed_policy'" EXIT

  local token
  token=$(get_token) # noqa: secret
  if [[ -z "$token" || "$token" == "null" ]]; then
    echo -e "${RED}Failed to get OAuth token${NC}"
    exit 1
  fi

  local has_changes=true
  if ! show_diff "$token" "$processed_policy"; then
    has_changes=false
  fi
  echo ""

  if ! validate_policy "$token" "$processed_policy"; then
    exit 1
  fi

  if $apply; then
    if $has_changes; then
      echo ""
      apply_policy "$token" "$processed_policy"
    else
      echo -e "${GREEN}Nothing to apply.${NC}"
    fi
  else
    echo ""
    if $has_changes; then
      echo -e "${YELLOW}Dry-run complete. Run with --apply to apply changes.${NC}"
    else
      echo -e "${GREEN}Policy is in sync. No action needed.${NC}"
    fi
  fi
}

main "$@"
