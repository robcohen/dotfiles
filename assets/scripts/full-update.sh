#!/run/current-system/sw/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Starting full system update..."
echo ""

echo "Step 1/3: Checking versions..."
"$SCRIPT_DIR/check-versions.sh"
echo ""

echo "Step 2/3: Updating system..."
"$SCRIPT_DIR/update-system.sh"
echo ""

echo "Step 3/3: Updating Home Manager..."
"$SCRIPT_DIR/update-home-manager.sh"

echo ""
echo "✅ Full update complete!"
