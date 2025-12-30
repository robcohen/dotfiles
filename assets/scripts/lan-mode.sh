#!/usr/bin/env bash
# lan-mode - Temporarily allow LAN access while using Tailscale exit node
#
# Usage:
#   lan-mode on      Enable LAN access (persistent until 'off')
#   lan-mode off     Disable LAN access (restore full tunnel)
#   lan-mode status  Show current LAN access status
#   lan-mode shell   Interactive shell with LAN access (reverts on exit)
#   lan-mode         Same as 'lan-mode shell'
#
# This uses Tailscale's --exit-node-allow-lan-access flag which allows
# traffic to local network while still routing internet through exit node.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

get_status() {
  if tailscale status --json 2>/dev/null | grep -q '"ExitNodeAllowLANAccess":true'; then
    echo "enabled"
  else
    echo "disabled"
  fi
}

enable_lan() {
  echo -e "${GREEN}Enabling LAN access...${NC}"
  tailscale set --exit-node-allow-lan-access=true
  echo -e "${GREEN}✓ LAN access enabled${NC}"
  echo ""
  echo "You can now access local network devices (router, printers, etc.)"
  echo "Internet traffic still routes through Tailscale exit node."
  echo ""
  echo "Run 'lan-mode off' to restore full tunnel protection."
}

disable_lan() {
  echo -e "${YELLOW}Disabling LAN access...${NC}"
  tailscale set --exit-node-allow-lan-access=false
  echo -e "${YELLOW}✓ LAN access disabled - full tunnel restored${NC}"
}

show_status() {
  local status
  status=$(get_status)

  echo "LAN Access Status"
  echo "================="

  if [[ "$status" == "enabled" ]]; then
    echo -e "Status: ${GREEN}ENABLED${NC}"
    echo "Local network devices are accessible."
  else
    echo -e "Status: ${YELLOW}DISABLED${NC}"
    echo "All traffic routes through Tailscale exit node."
  fi

  echo ""
  echo "Current exit node:"
  tailscale status | grep "exit node" || echo "  (no exit node active)"

  echo ""
  echo "Default gateway:"
  ip route | grep default | head -1 | awk '{print "  " $3 " via " $5}'
}

interactive_shell() {
  local previous_status
  previous_status=$(get_status)

  echo -e "${GREEN}=== LAN Mode Shell ===${NC}"
  echo ""

  # Enable LAN access
  if [[ "$previous_status" != "enabled" ]]; then
    enable_lan
  else
    echo -e "${GREEN}LAN access already enabled${NC}"
  fi

  echo ""
  echo -e "${YELLOW}Starting interactive shell...${NC}"
  echo -e "${YELLOW}LAN access will be REVERTED when you exit (Ctrl+D or 'exit')${NC}"
  echo ""

  # Trap to restore on exit
  trap 'echo ""; echo -e "${YELLOW}Exiting LAN mode...${NC}"; disable_lan' EXIT

  # Start interactive shell
  $SHELL
}

case "${1:-shell}" in
  on|enable)
    enable_lan
    ;;
  off|disable)
    disable_lan
    ;;
  status)
    show_status
    ;;
  shell|"")
    interactive_shell
    ;;
  -h|--help|help)
    echo "lan-mode - Temporarily allow LAN access while using Tailscale exit node"
    echo ""
    echo "Usage:"
    echo "  lan-mode on      Enable LAN access (persistent until 'off')"
    echo "  lan-mode off     Disable LAN access (restore full tunnel)"
    echo "  lan-mode status  Show current LAN access status"
    echo "  lan-mode shell   Interactive shell with LAN access (reverts on exit)"
    echo "  lan-mode         Same as 'lan-mode shell'"
    echo ""
    echo "This uses Tailscale's --exit-node-allow-lan-access flag."
    ;;
  *)
    echo "Unknown command: $1"
    echo "Run 'lan-mode --help' for usage."
    exit 1
    ;;
esac
