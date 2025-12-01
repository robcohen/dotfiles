#!/usr/bin/env bash

# Bluetooth Auto-Connect Script
# Automatically connects to Lenovo WL300 mouse and MX MCHNCL M keyboard

# Device MAC addresses
MOUSE_MAC="C2:97:63:14:57:EF"
MOUSE_NAME="Lenovo WL300"
KEYBOARD_MAC="D0:BF:D7:FF:C7:33"
KEYBOARD_NAME="MX MCHNCL M"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to ensure bluetooth is powered on
ensure_bluetooth_on() {
    log_info "Checking bluetooth adapter status..."

    local powered=$(bluetoothctl show | grep "Powered:" | awk '{print $2}')

    if [ "$powered" != "yes" ]; then
        log_info "Powering on bluetooth adapter..."
        bluetoothctl power on
        sleep 2
    else
        log_info "Bluetooth adapter is already powered on"
    fi
}

# Function to check if device is paired
is_paired() {
    local mac=$1
    bluetoothctl info "$mac" 2>/dev/null | grep -q "Paired: yes"
}

# Function to check if device is connected
is_connected() {
    local mac=$1
    bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"
}

# Function to check if device needs pairing
check_pairing() {
    local mac=$1
    local name=$2

    if ! is_paired "$mac"; then
        log_error "$name is not paired!"
        log_error "Please pair it manually first:"
        echo ""
        echo "  1. Run: bluetoothctl"
        echo "  2. Type: scan on"
        echo "  3. Type: pair $mac"
        echo "  4. Enter the PIN code shown on screen using your keyboard"
        echo "  5. Type: trust $mac"
        echo "  6. Type: exit"
        echo ""
        log_error "Then run this script again."
        return 1
    fi
    return 0
}

# Function to connect to device
connect_device() {
    local mac=$1
    local name=$2

    log_info "Connecting to $name ($mac)..."

    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if bluetoothctl connect "$mac" 2>/dev/null; then
            log_info "Successfully connected to $name"
            return 0
        else
            log_warn "Connection attempt $attempt failed for $name"
            attempt=$((attempt + 1))
            if [ $attempt -le $max_attempts ]; then
                sleep 2
            fi
        fi
    done

    log_error "Failed to connect to $name after $max_attempts attempts"
    return 1
}

# Function to process a single device
process_device() {
    local mac=$1
    local name=$2

    echo ""
    log_info "Processing $name..."

    # Check if already connected
    if is_connected "$mac"; then
        log_info "$name is already connected"
        return 0
    fi

    # Check if device is paired
    if ! check_pairing "$mac" "$name"; then
        return 1
    fi

    log_info "$name is already paired"

    # Connect to device
    connect_device "$mac" "$name"
}

# Main execution
main() {
    echo "========================================="
    log_info "Bluetooth Auto-Connect Script"
    echo "========================================="

    # Ensure bluetooth is on
    ensure_bluetooth_on

    local exit_code=0

    # Process mouse
    if ! process_device "$MOUSE_MAC" "$MOUSE_NAME"; then
        exit_code=1
    fi

    # Process keyboard
    if ! process_device "$KEYBOARD_MAC" "$KEYBOARD_NAME"; then
        exit_code=1
    fi

    echo ""
    if [ $exit_code -eq 0 ]; then
        echo "========================================="
        log_info "Connection process complete!"
        echo "========================================="
    else
        echo "========================================="
        log_error "Script failed - see errors above"
        echo "========================================="
        exit 1
    fi
}

main "$@"
