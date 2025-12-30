#!/run/current-system/sw/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --quick        Quick update (nixpkgs only, skip version checks)"
    echo "  --no-update    Skip flake update entirely"
    echo "  -h, --help     Show this help"
}

UPDATE_ARGS=""
SKIP_CHECKS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            UPDATE_ARGS="--quick"
            SKIP_CHECKS=true
            shift
            ;;
        --no-update)
            UPDATE_ARGS="--no-update"
            SKIP_CHECKS=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

echo "Starting full system update..."
echo ""

if [[ "$SKIP_CHECKS" != "true" ]]; then
    echo "Step 1/4: Checking versions..."
    "$SCRIPT_DIR/check-versions.sh"
    echo ""

    echo "Step 2/4: Checking browser extensions..."
    "$SCRIPT_DIR/update-browser-extensions.sh"
    echo ""
else
    echo "⏭️  Skipping version checks (quick mode)..."
    echo ""
fi

echo "Step 3/4: Updating system..."
"$SCRIPT_DIR/update-system.sh" $UPDATE_ARGS
echo ""

echo "Step 4/4: Updating Home Manager..."
"$SCRIPT_DIR/update-home-manager.sh"

echo ""
echo "Full update complete!"
