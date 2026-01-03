#!/usr/bin/env bash
# lan-mode - Manage LAN access while using Tailscale with exit node
#
# Usage:
#   lan-mode maintenance  Disconnect exit node for LAN access (keeps Tailscale for DNS)
#   lan-mode restore      Reconnect to exit node
#   lan-mode status       Show current status
#
# Note: Your LAN (100.110.x.x) overlaps with Tailscale's CGNAT range (100.64.0.0/10)
# so --exit-node-allow-lan-access won't work. Use 'maintenance' mode instead.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# State file to remember the previous exit node
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/lan-mode-exit-node"

get_current_exit_node() {
  tailscale status --json 2>/dev/null | jq -r '.ExitNodeStatus.TailscaleIPs[0] // empty' 2>/dev/null || true
}

get_exit_node_name() {
  # Look for "offers exit node" or active exit node marker in status
  tailscale status --json 2>/dev/null | jq -r '
    .Peer as $peers |
    to_entries[] |
    select(.value.ExitNode == true) |
    .value.HostName // empty
  ' 2>/dev/null || true
}

show_status() {
  echo -e "${BLUE}LAN Mode Status${NC}"
  echo "==============="

  local exit_node
  exit_node=$(get_exit_node_name)

  if [[ -n "$exit_node" ]]; then
    echo -e "Exit Node: ${YELLOW}$exit_node${NC}"
    echo -e "LAN Access: ${RED}BLOCKED${NC} (traffic routes through exit node)"
  else
    echo -e "Exit Node: ${GREEN}None${NC}"
    echo -e "LAN Access: ${GREEN}AVAILABLE${NC}"
  fi

  if [[ -f "$STATE_FILE" ]]; then
    echo -e "Saved Node: $(cat "$STATE_FILE")"
  fi

  # Show DNS mode
  DNS_STATE_FILE="$HOME/.config/waybar/dns-mode"
  if [[ -f "$DNS_STATE_FILE" ]]; then
    local dns_mode
    dns_mode=$(cat "$DNS_STATE_FILE")
    case "$dns_mode" in
      "close") echo -e "DNS Mode: ${RED}Close${NC} (fail-closed, Tailscale only)" ;;
      "open") echo -e "DNS Mode: ${GREEN}Open${NC} (Quad9 fallback)" ;;
      "mull") echo -e "DNS Mode: ${YELLOW}Mull${NC} (Mullvad DNS)" ;;
      *) echo -e "DNS Mode: ${BLUE}Unknown${NC}" ;;
    esac
  fi

  echo ""
  echo "Network interfaces:"
  ip -br addr | grep -E "^(enp|wlp|eth)" | head -3

  echo ""
  echo "Default gateway:"
  ip route | grep default | head -1 | awk '{print "  " $3 " via " $5}'

  echo ""
  echo "DNS servers (tailscale0):"
  resolvectl dns tailscale0 2>/dev/null | sed 's/.*: /  /' || echo "  unknown"
}

enter_maintenance() {
  local current_node
  current_node=$(get_exit_node_name)

  if [[ -z "$current_node" ]]; then
    echo -e "${GREEN}Already in maintenance mode (no exit node active)${NC}"
    return 0
  fi

  echo -e "${YELLOW}Entering maintenance mode...${NC}"

  # Save current exit node for later
  echo "$current_node" > "$STATE_FILE"
  echo "  Saved exit node: $current_node"

  # Save current DNS mode and switch to Open for reliability
  DNS_STATE_FILE="$HOME/.config/waybar/dns-mode"
  if [[ -f "$DNS_STATE_FILE" ]]; then
    cp "$DNS_STATE_FILE" "${STATE_FILE}.dns-backup"
    echo "  Saved DNS mode: $(cat "$DNS_STATE_FILE")"
  fi
  # Switch to Open DNS mode (Quad9 fallback) for LAN reliability
  mkdir -p "$HOME/.config/waybar"
  echo "open" > "$DNS_STATE_FILE"
  sudo resolvectl dns tailscale0 100.100.100.100 9.9.9.9 149.112.112.112 2>/dev/null || true
  echo "  Switched DNS to: Open (Quad9 fallback)"

  # Disconnect from exit node (keeps Tailscale running for DNS)
  tailscale set --exit-node=

  # Signal waybar to refresh
  pkill -RTMIN+9 waybar 2>/dev/null || true

  echo -e "${GREEN}✓ Maintenance mode enabled${NC}"
  echo ""
  echo "You can now access LAN devices (router at 192.168.1.1, etc.)"
  echo "Internet traffic goes through your ISP (not VPN protected)."
  echo "DNS switched to Open mode for reliability."
  echo ""
  echo -e "Run '${BLUE}lan-mode restore${NC}' to reconnect to exit node."
}

exit_maintenance() {
  if [[ ! -f "$STATE_FILE" ]]; then
    echo -e "${YELLOW}No saved exit node found.${NC}"
    echo "Use 'mullvad-connect' to select an exit node, or specify one:"
    echo "  tailscale set --exit-node=<node>"
    return 1
  fi

  local saved_node
  saved_node=$(cat "$STATE_FILE")

  echo -e "${YELLOW}Restoring exit node...${NC}"
  echo "  Connecting to: $saved_node"

  tailscale set --exit-node="$saved_node"

  # Restore previous DNS mode if saved
  DNS_STATE_FILE="$HOME/.config/waybar/dns-mode"
  DNS_BACKUP="${STATE_FILE}.dns-backup"
  if [[ -f "$DNS_BACKUP" ]]; then
    local saved_dns
    saved_dns=$(cat "$DNS_BACKUP")
    echo "  Restoring DNS mode: $saved_dns"
    cp "$DNS_BACKUP" "$DNS_STATE_FILE"
    rm -f "$DNS_BACKUP"

    # Apply the DNS setting
    case "$saved_dns" in
      "close")
        sudo resolvectl dns tailscale0 100.100.100.100 2>/dev/null || true
        ;;
      "open")
        sudo resolvectl dns tailscale0 100.100.100.100 9.9.9.9 149.112.112.112 2>/dev/null || true
        ;;
      "mull")
        sudo resolvectl dns tailscale0 194.242.2.4 2>/dev/null || true
        ;;
    esac
  else
    # Default to closed mode when restoring
    echo "  Restoring DNS mode: close (default)"
    echo "close" > "$DNS_STATE_FILE"
    sudo resolvectl dns tailscale0 100.100.100.100 2>/dev/null || true
  fi

  rm -f "$STATE_FILE"

  # Signal waybar to refresh
  pkill -RTMIN+9 waybar 2>/dev/null || true

  echo -e "${GREEN}✓ Exit node restored${NC}"
  echo "Traffic is now routed through VPN."
}

case "${1:-status}" in
  maintenance|maint|m)
    enter_maintenance
    ;;
  restore|r)
    exit_maintenance
    ;;
  status|s)
    show_status
    ;;
  -h|--help|help)
    echo "lan-mode - Manage LAN access with Tailscale exit node"
    echo ""
    echo "Your LAN (100.110.x.x) overlaps with Tailscale's CGNAT range,"
    echo "so this script disconnects from the exit node for LAN access."
    echo ""
    echo "Usage:"
    echo "  lan-mode maintenance  Disconnect exit node for LAN access"
    echo "  lan-mode restore      Reconnect to previous exit node"
    echo "  lan-mode status       Show current status (default)"
    echo ""
    echo "Shortcuts: m=maintenance, r=restore, s=status"
    ;;
  *)
    echo "Unknown command: $1"
    echo "Run 'lan-mode --help' for usage."
    exit 1
    ;;
esac
