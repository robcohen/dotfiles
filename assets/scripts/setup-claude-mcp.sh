#!/usr/bin/env bash
# Setup Claude Code MCP servers # noqa: secret
# Run this after fresh install or to reset MCP configuration
#
# Required environment variables (add to ~/.env or similar):
#   EXA_API_KEY          - From dashboard.exa.ai/api-keys
#   SLACK_BOT_TOKEN      - From Slack app OAuth
#   SLACK_TEAM_ID        - Your Slack workspace ID
#   GOOGLE_OAUTH_CREDENTIALS - Google OAuth JSON (base64 or path)
#   OBSIDIAN_VAULT_PATH  - Path to your Obsidian vault

set -euo pipefail

# Source env file if it exists
ENV_FILE="${HOME}/Documents/dotfiles/.env"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

echo "Setting up Claude Code MCP servers..."

# Track which servers to add
declare -a SERVERS_TO_ADD=()

# === Basic servers (no auth required) ===
SERVERS_TO_ADD+=(
  "context7|npx -y @upstash/context7-mcp"
  "playwright|npx -y @playwright/mcp@latest --browser chrome"
)

# === Exa (semantic search) ===
if [[ -n "${EXA_API_KEY:-}" ]]; then
  SERVERS_TO_ADD+=("exa|npx -y exa-mcp-server")
  echo "  [+] exa: API key found"
else
  echo "  [-] exa: Skipping (EXA_API_KEY not set)"
fi

# === Obsidian (notes) ===
if [[ -n "${OBSIDIAN_VAULT_PATH:-}" && -d "${OBSIDIAN_VAULT_PATH:-}" ]]; then
  SERVERS_TO_ADD+=("obsidian|npx -y mcp-obsidian ${OBSIDIAN_VAULT_PATH}")
  echo "  [+] obsidian: Vault found at ${OBSIDIAN_VAULT_PATH}"
else
  echo "  [-] obsidian: Skipping (OBSIDIAN_VAULT_PATH not set or doesn't exist)"
fi

# === Slack ===
if [[ -n "${SLACK_BOT_TOKEN:-}" && -n "${SLACK_TEAM_ID:-}" ]]; then
  SERVERS_TO_ADD+=("slack|npx -y @modelcontextprotocol/server-slack")
  echo "  [+] slack: Credentials found"
else
  echo "  [-] slack: Skipping (SLACK_BOT_TOKEN or SLACK_TEAM_ID not set)"
fi

# === Google Calendar ===
if [[ -n "${GOOGLE_OAUTH_CREDENTIALS:-}" ]]; then
  SERVERS_TO_ADD+=("google-calendar|npx -y @cocal/google-calendar-mcp")
  echo "  [+] google-calendar: Credentials found"
else
  echo "  [-] google-calendar: Skipping (GOOGLE_OAUTH_CREDENTIALS not set)"
fi

echo ""

# Remove existing servers
echo "Removing existing MCP servers..."
for entry in "${SERVERS_TO_ADD[@]}"; do
  name="${entry%%|*}"
  claude mcp remove "$name" 2>/dev/null || true
done

# Add servers
echo "Adding MCP servers..."
for entry in "${SERVERS_TO_ADD[@]}"; do
  name="${entry%%|*}"
  cmd="${entry#*|}"
  echo "  Adding $name..."

  # Build env args based on server
  env_args=""
  case "$name" in
    exa)
      env_args="-e EXA_API_KEY=${EXA_API_KEY}" # noqa: secret
      ;;
    slack)
      env_args="-e SLACK_BOT_TOKEN=${SLACK_BOT_TOKEN} -e SLACK_TEAM_ID=${SLACK_TEAM_ID}" # noqa: secret
      ;;
    google-calendar)
      env_args="-e GOOGLE_OAUTH_CREDENTIALS=${GOOGLE_OAUTH_CREDENTIALS}"
      ;;
  esac

  # shellcheck disable=SC2086
  if [[ -n "$env_args" ]]; then
    claude mcp add $env_args "$name" -- $cmd
  else
    claude mcp add "$name" -- $cmd
  fi
done

echo ""
echo "MCP servers configured. Reload Claude Code and run /mcp to verify."
echo ""
echo "Configured servers:"
claude mcp list
