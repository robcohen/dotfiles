#!/usr/bin/env bash
#
# Sync Control D configuration from local HuJSON files
#
# Prerequisites:
#   1. Create API token at: https://controld.com/dashboard/settings → API Keys
#      - Permission needed: Write (for full management)
#   2. Set environment variables in ../.env:
#      CONTROLD_API_KEY="..."
#
# Usage:
#   ./sync.sh                     # Show current config
#   ./sync.sh profiles            # List all profiles
#   ./sync.sh devices             # List all devices/endpoints
#   ./sync.sh rules <profile_pk>  # List rules for a profile
#   ./sync.sh diff <file.hujson>  # Compare local vs remote
#   ./sync.sh import <file.hujson> [--apply]  # Sync from HuJSON
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
API_BASE="https://api.controld.com"

# Source .env file if it exists
if [[ -f "${REPO_ROOT}/.env" ]]; then
  # shellcheck source=/dev/null
  source "${REPO_ROOT}/.env"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check prerequisites
check_env() {
  local missing=0
  if [[ -z "${CONTROLD_API_KEY:-}" ]]; then
    echo -e "${RED}Missing required env var: CONTROLD_API_KEY${NC}"
    missing=1
  fi
  if [[ $missing -eq 1 ]]; then
    echo ""
    echo "Create API token at: https://controld.com/dashboard/settings → API Keys"
    echo "Required permission: Write"
    exit 1
  fi
}

# Check env vars needed for import
check_import_env() {
  if [[ -z "${CONTROLD_PROFILE_PK:-}" ]]; then
    echo -e "${RED}Missing required env var: CONTROLD_PROFILE_PK${NC}"
    echo ""
    echo "Find your profile PK: ./sync.sh profiles"
    echo "Then add to .env: CONTROLD_PROFILE_PK=your-pk-here"
    exit 1
  fi
}

# API request helper
api() {
  local method="$1"
  local endpoint="$2"
  shift 2

  curl -s -X "$method" "${API_BASE}${endpoint}" \
    -H "Authorization: Bearer ${CONTROLD_API_KEY}" \
    -H "Content-Type: application/json" \
    "$@"
}

# Strip HuJSON comments to get valid JSON
strip_hujson() {
  sed 's|//.*||g' | tr '\n' ' ' | sed 's/,[ ]*}/}/g; s/,[ ]*\]/]/g' | tr -s ' '
}

# Substitute environment variables in content
substitute_env_vars() {
  sed -e "s|\${CONTROLD_PROFILE_PK}|${CONTROLD_PROFILE_PK:-}|g" \
      -e "s|\${CONTROLD_RESOLVER_ID}|${CONTROLD_RESOLVER_ID:-}|g"
}

# Read and parse HuJSON file (with env var substitution)
read_hujson() {
  local file="$1"
  cat "$file" | substitute_env_vars | strip_hujson | jq '.'
}

# List all profiles
list_profiles() {
  echo -e "${CYAN}=== Profiles ===${NC}"
  local response
  response=$(api GET /profiles)

  if echo "$response" | jq -e '.body.profiles' > /dev/null 2>&1; then
    echo "$response" | jq -r '.body.profiles[] | "PK: \(.PK) | Name: \(.name)"'
    echo ""
    echo -e "${YELLOW}Use 'PK' value for other commands${NC}"
  else
    echo -e "${RED}Failed to list profiles:${NC}"
    echo "$response" | jq '.'
  fi
}

# List all devices/endpoints
list_devices() {
  echo -e "${CYAN}=== Devices/Endpoints ===${NC}"
  local response
  response=$(api GET /devices)

  if echo "$response" | jq -e '.body.devices' > /dev/null 2>&1; then
    echo "$response" | jq -r '.body.devices[] | "PK: \(.PK) | Name: \(.name) | Resolver: \(.resolvers.uid // "N/A") | Profile: \(.profile.PK // "none")"'
  else
    echo -e "${RED}Failed to list devices:${NC}"
    echo "$response" | jq '.'
  fi
}

# List rules for a profile
list_rules() {
  local profile_pk="$1"
  echo -e "${CYAN}=== Custom Rules for ${profile_pk} ===${NC}"

  local response
  response=$(api GET "/profiles/${profile_pk}/rules")

  if echo "$response" | jq -e '.body.rules' > /dev/null 2>&1; then
    local count
    count=$(echo "$response" | jq '.body.rules | length')
    echo -e "Total rules: ${GREEN}${count}${NC}"
    if [[ "$count" -gt 0 ]]; then
      echo ""
      echo "$response" | jq -r '.body.rules[] | "[\(.action.do // "default")] \(.hostnames | join(", "))"'
    fi
  else
    echo -e "${RED}Failed to list rules:${NC}"
    echo "$response" | jq '.'
  fi
}

# Get current filter status for a profile
get_remote_filters() {
  local profile_pk="$1"
  api GET "/profiles/${profile_pk}/filters" | jq '[.body.filters[] | select(.status == 1) | {key: .PK, value: (if .action.lvl then .action.lvl else true end)}] | from_entries'
}

# Get current rules for a profile
get_remote_rules() {
  local profile_pk="$1"
  api GET "/profiles/${profile_pk}/rules" | jq '.body.rules // []'
}

# Map our simplified filter names to Control D API
# Returns: filter_name level (e.g., "ads relaxed" or "malware strict")
map_filter() {
  local name="$1"
  local value="$2"

  case "$name" in
    ads)
      case "$value" in
        relaxed) echo "ads_small" ;;
        balanced) echo "ads_medium" ;;
        strict) echo "ads" ;;
        *) echo "ads_small" ;;
      esac
      ;;
    malware)
      case "$value" in
        relaxed) echo "malware" ;;
        balanced) echo "ip_malware" ;;
        strict) echo "ai_malware" ;;
        *) echo "malware" ;;
      esac
      ;;
    phishing) echo "typo" ;;
    clickbait) echo "fakenews" ;;
    iot) echo "iot" ;;
    adult) echo "porn" ;;
    gambling) echo "gambling" ;;
    social) echo "social" ;;
    gaming) echo "games" ;;
    crypto) echo "cryptominers" ;;
    drugs) echo "drugs" ;;
    torrents) echo "torrents" ;;
    dating) echo "dating" ;;
    new_domains)
      case "$value" in
        week) echo "nrd_small" ;;
        month) echo "nrd" ;;
        *) echo "nrd_small" ;;
      esac
      ;;
    *) echo "$name" ;;  # Pass through unknown names
  esac
}

# Show diff between local HuJSON and remote config
diff_config() {
  local config_file="$1"

  if [[ ! -f "$config_file" ]]; then
    echo -e "${RED}Config file not found: ${config_file}${NC}"
    exit 1
  fi

  local config
  config=$(read_hujson "$config_file")

  local profile_pk
  profile_pk=$(echo "$config" | jq -r '.profile_pk')

  if [[ -z "$profile_pk" || "$profile_pk" == "null" ]]; then
    echo -e "${RED}Missing profile_pk in config file${NC}"
    exit 1
  fi

  echo -e "${CYAN}=== Diff: ${config_file} vs Remote ===${NC}"
  echo -e "Profile: ${profile_pk}"
  echo ""

  # Compare rules
  echo -e "${YELLOW}Custom Rules:${NC}"
  local local_rules remote_rules
  local_rules=$(echo "$config" | jq '.rules // []')
  remote_rules=$(get_remote_rules "$profile_pk")

  local local_count remote_count
  local_count=$(echo "$local_rules" | jq 'length')
  remote_count=$(echo "$remote_rules" | jq 'length')

  echo "Local:  ${local_count} rules"
  echo "Remote: ${remote_count} rules"
  echo ""

  # Compare services
  echo -e "${YELLOW}Services:${NC}"
  local local_services
  local_services=$(echo "$config" | jq '.services // {}')
  echo "Local:  $(echo "$local_services" | jq -c '.')"
  echo ""

  # Note about filters
  echo -e "${YELLOW}Filters:${NC} (read-only, manage via dashboard)"
  get_remote_filters "$profile_pk" | jq -c '.'
}

# Sync filters to remote
sync_filters() {
  local profile_pk="$1"
  local filters="$2"

  echo -e "${YELLOW}Syncing filters...${NC}"

  # First, get all available filters and disable them
  local available
  available=$(api GET "/profiles/${profile_pk}/filters" | jq -r '.body.filters[].PK')

  # Disable all filters first (clean slate)
  for filter_pk in $available; do
    api PUT "/profiles/${profile_pk}/filters/${filter_pk}" -d '{"status": 0}' > /dev/null 2>&1 || true
  done

  # Enable filters from config
  echo "$filters" | jq -r 'to_entries[] | "\(.key) \(.value)"' | while read -r name value; do
    local filter_pk
    filter_pk=$(map_filter "$name" "$value")

    if [[ -n "$filter_pk" ]]; then
      local response
      response=$(api PUT "/profiles/${profile_pk}/filters/${filter_pk}" -d '{"status": 1}')

      if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} ${name} (${filter_pk})"
      else
        echo -e "  ${RED}✗${NC} ${name}: $(echo "$response" | jq -r '.error.message // "unknown error"')"
      fi
    fi
  done
}

# Sync rules to remote
sync_rules() {
  local profile_pk="$1"
  local rules="$2"

  local count
  count=$(echo "$rules" | jq 'length')

  if [[ "$count" -eq 0 ]]; then
    echo -e "${YELLOW}No custom rules to sync${NC}"
    return
  fi

  echo -e "${YELLOW}Syncing ${count} custom rules...${NC}"

  # Convert our simplified format to API format
  local api_rules
  api_rules=$(echo "$rules" | jq '[.[] | {
    hostnames: [.hostname],
    action: {
      do: (if .action == "block" then 0 elif .action == "bypass" then 1 else 1 end),
      status: (if .action == "block" then 0 else 1 end)
    }
  }]')

  local response
  response=$(api PUT "/profiles/${profile_pk}/rules" -d "{\"rules\": $api_rules}")

  if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Rules synced"
  else
    echo -e "  ${RED}✗${NC} Failed: $(echo "$response" | jq -r '.error.message // "unknown error"')"
  fi
}

# Import/sync from HuJSON config
import_config() {
  local config_file="$1"
  local apply="${2:-false}"

  # Check for required env vars
  check_import_env

  if [[ ! -f "$config_file" ]]; then
    echo -e "${RED}Config file not found: ${config_file}${NC}"
    exit 1
  fi

  local config
  config=$(read_hujson "$config_file")

  local profile_pk profile_name
  profile_pk=$(echo "$config" | jq -r '.profile_pk')
  profile_name=$(echo "$config" | jq -r '.name // "unknown"')

  if [[ -z "$profile_pk" || "$profile_pk" == "null" ]]; then
    echo -e "${RED}Missing profile_pk in config file${NC}"
    exit 1
  fi

  echo -e "${CYAN}=== Syncing: ${profile_name} (${profile_pk}) ===${NC}"
  echo ""

  # Show diff first
  diff_config "$config_file"
  echo ""

  if [[ "$apply" != "true" ]]; then
    echo -e "${YELLOW}Dry-run complete. Run with --apply to apply changes.${NC}"
    return
  fi

  echo -e "${CYAN}=== Applying Changes ===${NC}"
  echo ""

  # Sync rules
  local rules
  rules=$(echo "$config" | jq '.rules // []')
  sync_rules "$profile_pk" "$rules"
  echo ""

  # Note about filters
  echo -e "${YELLOW}Note:${NC} Filters must be configured via dashboard: https://controld.com/dashboard"
  echo ""

  echo -e "${GREEN}Sync complete!${NC}"
}

# Show status overview
show_status() {
  echo -e "${CYAN}=== Control D Status ===${NC}"
  echo ""

  local user
  user=$(api GET /users)
  if echo "$user" | jq -e '.body.email' > /dev/null 2>&1; then
    echo -e "Account: ${GREEN}$(echo "$user" | jq -r '.body.email')${NC}"
  fi
  echo ""

  list_profiles
  echo ""
  list_devices
}

# Print usage
usage() {
  echo "Usage: $0 [command] [args]"
  echo ""
  echo "Commands:"
  echo "  (none)              Show status overview"
  echo "  profiles            List all profiles"
  echo "  devices             List all devices/endpoints"
  echo "  rules <profile_pk>  List custom rules for a profile"
  echo "  diff <file.hujson>  Compare local config with remote"
  echo "  import <file.hujson> [--apply]  Sync profile from HuJSON"
  echo ""
  echo "Examples:"
  echo "  $0                                    # Show overview"
  echo "  $0 diff profiles/developer.hujson    # Preview changes"
  echo "  $0 import profiles/developer.hujson --apply  # Apply changes"
}

main() {
  check_env

  local cmd="${1:-status}"

  case "$cmd" in
    status|"")
      show_status
      ;;
    profiles)
      list_profiles
      ;;
    devices)
      list_devices
      ;;
    rules)
      if [[ -z "${2:-}" ]]; then
        echo -e "${RED}Usage: $0 rules <profile_pk>${NC}"
        exit 1
      fi
      list_rules "$2"
      ;;
    diff)
      if [[ -z "${2:-}" ]]; then
        echo -e "${RED}Usage: $0 diff <config.hujson>${NC}"
        exit 1
      fi
      diff_config "$2"
      ;;
    import|sync)
      if [[ -z "${2:-}" ]]; then
        echo -e "${RED}Usage: $0 import <config.hujson> [--apply]${NC}"
        exit 1
      fi
      local apply=false
      if [[ "${3:-}" == "--apply" ]]; then
        apply=true
      fi
      import_config "$2" "$apply"
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      echo -e "${RED}Unknown command: ${cmd}${NC}"
      usage
      exit 1
      ;;
  esac
}

main "$@"
