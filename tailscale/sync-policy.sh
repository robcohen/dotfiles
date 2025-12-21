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
  for var in TS_OAUTH_CLIENT_ID TS_OAUTH_SECRET TS_TAILNET; do
    if [[ -z "${!var:-}" ]]; then
      echo -e "${RED}Missing required env var: ${var}${NC}"
      missing=1
    fi
  done
  if [[ $missing -eq 1 ]]; then
    echo ""
    echo "Create OAuth client at: https://login.tailscale.com/admin/settings/oauth"
    echo "Required scope: acl (read/write)"
    exit 1
  fi
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
  local token="$1"
  curl -s "https://api.tailscale.com/api/v2/tailnet/${TS_TAILNET}/acl" \
    -H "Authorization: Bearer ${token}"
}

# Validate policy (dry-run)
validate_policy() {
  local token="$1"
  echo -e "${YELLOW}Validating policy...${NC}"

  local response
  response=$(curl -s -w "\n%{http_code}" \
    "https://api.tailscale.com/api/v2/tailnet/${TS_TAILNET}/acl/validate" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/hujson" \
    --data-binary "@${POLICY_FILE}")

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
  local token="$1"
  echo -e "${YELLOW}Applying policy...${NC}"

  local response
  response=$(curl -s -w "\n%{http_code}" \
    "https://api.tailscale.com/api/v2/tailnet/${TS_TAILNET}/acl" \
    -X POST \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/hujson" \
    --data-binary "@${POLICY_FILE}")

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

# Strip comments from HuJSON for parsing
strip_comments() {
  # Remove // comments and trailing commas (basic HuJSON -> JSON)
  sed -e 's|//.*||g' -e 's/,[[:space:]]*}/}/g' -e 's/,[[:space:]]*\]/]/g' | tr -d '\n' | tr -s ' '
}

# Show diff between current and new policy
show_diff() {
  local token="$1"
  echo -e "${YELLOW}Current vs new policy:${NC}"

  local current
  current=$(get_current_policy "$token" | strip_comments | jq -S '.' 2>/dev/null || get_current_policy "$token")
  local new
  new=$(cat "$POLICY_FILE" | strip_comments | jq -S '.' 2>/dev/null || cat "$POLICY_FILE")

  diff -u <(echo "$current") <(echo "$new") || true
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

  local token
  token=$(get_token)
  if [[ -z "$token" || "$token" == "null" ]]; then
    echo -e "${RED}Failed to get OAuth token${NC}"
    exit 1
  fi

  show_diff "$token"
  echo ""

  if ! validate_policy "$token"; then
    exit 1
  fi

  if $apply; then
    echo ""
    apply_policy "$token"
  else
    echo ""
    echo -e "${YELLOW}Dry-run complete. Run with --apply to apply changes.${NC}"
  fi
}

main "$@"
