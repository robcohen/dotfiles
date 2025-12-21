#!/run/current-system/sw/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Starting full system update..."
echo ""

echo "Step 1/4: Checking versions..."
"$SCRIPT_DIR/check-versions.sh"
echo ""

echo "Step 2/4: Checking browser extensions..."
"$SCRIPT_DIR/update-browser-extensions.sh"
echo ""

echo "Step 3/4: Updating system..."
"$SCRIPT_DIR/update-system.sh"
echo ""

echo "Step 4/4: Updating Home Manager..."
"$SCRIPT_DIR/update-home-manager.sh"

echo ""
echo "Full update complete!"
