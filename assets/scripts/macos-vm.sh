#!/usr/bin/env bash
#
# macOS VM launcher using QEMU/KVM
# Based on OSX-KVM project: https://github.com/kholia/OSX-KVM
#
# Prerequisites:
#   1. Download OpenCore image and macOS installer
#   2. Create VM directory with required files
#
# Setup (run once):
#   mkdir -p ~/VMs/macos
#   cd ~/VMs/macos
#   # Clone OSX-KVM for OpenCore and scripts
#   git clone --depth 1 https://github.com/kholia/OSX-KVM.git
#   cd OSX-KVM
#   # Fetch macOS installer (choose version interactively)
#   ./fetch-macOS-v2.py
#   # Convert to disk image
#   dmg2img -i BaseSystem.dmg BaseSystem.img
#   # Create main disk
#   qemu-img create -f qcow2 ../macos-disk.qcow2 128G
#   # Copy OpenCore image
#   cp OpenCore/OpenCore.qcow2 ../
#
# Usage:
#   ./macos-vm.sh              # Run existing installation
#   ./macos-vm.sh --install    # Boot installer for fresh install

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

# VM Directory
if [ -n "${SUDO_USER:-}" ]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    USER_HOME="$HOME"
fi
VM_DIR="${MACOS_VM_DIR:-$USER_HOME/VMs/macos}"

# VM Settings
VM_NAME="macos"
CPU_CORES="${MACOS_CORES:-4}"
CPU_THREADS="${MACOS_THREADS:-2}"
RAM="${MACOS_RAM:-8G}"
DISK_SIZE="${MACOS_DISK_SIZE:-128G}"

# Display settings
DISPLAY_MODE="${MACOS_DISPLAY:-sdl}"  # sdl, gtk, spice, vnc
RESOLUTION="${MACOS_RESOLUTION:-1920x1080}"

# Files
OPENCORE_IMG="$VM_DIR/OpenCore.qcow2"
MACOS_DISK="$VM_DIR/macos-disk.qcow2"
INSTALLER_IMG="$VM_DIR/OSX-KVM/BaseSystem.img"
OVMF_CODE=$(find /nix/store -name "OVMF_CODE.fd" -path "*OVMF*" 2>/dev/null | head -1)

# =============================================================================
# Functions
# =============================================================================

print_help() {
    cat << 'EOF'
macOS VM Launcher

Usage: macos-vm.sh [OPTIONS]

Options:
    --install       Boot from installer (for fresh installation)
    --vnc           Use VNC display (port 5900)
    --spice         Use SPICE display (port 5930)
    --cores N       Set CPU cores (default: 4)
    --ram SIZE      Set RAM size (default: 8G)
    --help          Show this help

Environment Variables:
    MACOS_VM_DIR       VM directory (default: ~/VMs/macos)
    MACOS_CORES        CPU cores (default: 4)
    MACOS_THREADS      CPU threads (default: 2)
    MACOS_RAM          RAM size (default: 8G)
    MACOS_DISPLAY      Display mode: sdl, gtk, vnc, spice (default: sdl)
    MACOS_RESOLUTION   Screen resolution (default: 1920x1080)

First-time Setup:
    mkdir -p ~/VMs/macos && cd ~/VMs/macos
    git clone --depth 1 https://github.com/kholia/OSX-KVM.git
    cd OSX-KVM
    ./fetch-macOS-v2.py          # Download macOS (interactive)
    dmg2img -i BaseSystem.dmg BaseSystem.img
    qemu-img create -f qcow2 ../macos-disk.qcow2 128G
    cp OpenCore/OpenCore.qcow2 ../

Then run: macos-vm.sh --install
EOF
}

check_prerequisites() {
    local missing=()

    if [ ! -d "$VM_DIR" ]; then
        missing+=("VM directory: $VM_DIR")
    fi

    if [ ! -f "$OPENCORE_IMG" ]; then
        missing+=("OpenCore image: $OPENCORE_IMG")
    fi

    if [ ! -f "$MACOS_DISK" ]; then
        echo "Creating macOS disk image ($DISK_SIZE)..."
        qemu-img create -f qcow2 "$MACOS_DISK" "$DISK_SIZE"
    fi

    if [ -z "$OVMF_CODE" ]; then
        missing+=("OVMF firmware (install OVMF package)")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo "Error: Missing prerequisites:"
        printf '  - %s\n' "${missing[@]}"
        echo ""
        echo "Run with --help for setup instructions."
        exit 1
    fi
}

generate_mac_address() {
    # Generate Apple-like MAC address (starts with common Apple prefixes)
    printf '52:54:00:%02X:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))
}

# =============================================================================
# Parse Arguments
# =============================================================================

INSTALL_MODE=false
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --install)
            INSTALL_MODE=true
            shift
            ;;
        --vnc)
            DISPLAY_MODE="vnc"
            shift
            ;;
        --spice)
            DISPLAY_MODE="spice"
            shift
            ;;
        --cores)
            CPU_CORES="$2"
            shift 2
            ;;
        --ram)
            RAM="$2"
            shift 2
            ;;
        --help|-h)
            print_help
            exit 0
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

# =============================================================================
# Main
# =============================================================================

cd "$VM_DIR" 2>/dev/null || {
    echo "Error: VM directory $VM_DIR not found."
    echo "Run with --help for setup instructions."
    exit 1
}

check_prerequisites

# Create OVMF_VARS if needed
if [ ! -f "OVMF_VARS.fd" ]; then
    OVMF_VARS_TEMPLATE=$(find /nix/store -name "OVMF_VARS.fd" -path "*OVMF*" 2>/dev/null | head -1)
    if [ -n "$OVMF_VARS_TEMPLATE" ]; then
        cp "$OVMF_VARS_TEMPLATE" "OVMF_VARS.fd"
        chmod 644 "OVMF_VARS.fd"
    fi
fi

# Generate consistent MAC address (stored in file for persistence)
if [ ! -f ".mac_address" ]; then
    generate_mac_address > .mac_address
fi
MAC_ADDRESS=$(cat .mac_address)

# Build display arguments
case $DISPLAY_MODE in
    vnc)
        DISPLAY_ARGS="-display vnc=:0 -vnc :0"
        echo "VNC server starting on port 5900"
        ;;
    spice)
        DISPLAY_ARGS="-display spice-app -spice port=5930,disable-ticketing=on"
        echo "SPICE server starting on port 5930"
        ;;
    gtk)
        DISPLAY_ARGS="-display gtk,gl=on"
        ;;
    *)
        DISPLAY_ARGS="-display sdl"
        ;;
esac

# Build drive arguments
DRIVE_ARGS=(
    # OpenCore bootloader (boot drive)
    "-drive" "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
    "-drive" "if=pflash,format=raw,file=$VM_DIR/OVMF_VARS.fd"
    "-device" "virtio-blk-pci,drive=OpenCore,bootindex=1"
    "-drive" "id=OpenCore,if=none,format=qcow2,file=$OPENCORE_IMG"
    # Main macOS disk
    "-device" "virtio-blk-pci,drive=MacHDD,bootindex=2"
    "-drive" "id=MacHDD,if=none,format=qcow2,file=$MACOS_DISK"
)

# Add installer if in install mode
if [ "$INSTALL_MODE" = true ]; then
    if [ ! -f "$INSTALLER_IMG" ]; then
        echo "Error: Installer image not found: $INSTALLER_IMG"
        echo "Run OSX-KVM/fetch-macOS-v2.py and dmg2img first."
        exit 1
    fi
    DRIVE_ARGS+=(
        "-device" "virtio-blk-pci,drive=Installer,bootindex=3"
        "-drive" "id=Installer,if=none,format=raw,file=$INSTALLER_IMG"
    )
    echo "Install mode: Booting with macOS installer attached"
fi

echo "Starting macOS VM..."
echo "  CPU: $CPU_CORES cores x $CPU_THREADS threads"
echo "  RAM: $RAM"
echo "  Display: $DISPLAY_MODE"

# QEMU command
# Key settings for macOS:
# - cpu: Penryn base with required features for macOS
# - smbios: Apple Mac model identification
# - device isa-applesmc: Required for macOS boot
exec qemu-system-x86_64 \
    -name "$VM_NAME,process=$VM_NAME" \
    -pidfile "$VM_DIR/$VM_NAME.pid" \
    -enable-kvm \
    -machine q35,smm=on,vmport=off \
    -global ICH9-LPC.disable_s3=1 \
    -global ICH9-LPC.acpi-pci-hotplug-with-bridge-support=off \
    -cpu Penryn,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check \
    -smp "cores=$CPU_CORES,threads=$CPU_THREADS,sockets=1" \
    -m "$RAM" \
    -device virtio-vga-gl \
    $DISPLAY_ARGS \
    -device intel-hda \
    -device hda-duplex \
    -device ich9-intel-hda \
    -device hda-output \
    -usb \
    -device usb-kbd \
    -device usb-tablet \
    -device virtio-net-pci,netdev=net0,mac="$MAC_ADDRESS" \
    -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::5900-:5900 \
    -device virtio-rng-pci \
    -smbios type=2 \
    -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc" \
    "${DRIVE_ARGS[@]}" \
    -monitor unix:"$VM_DIR/$VM_NAME-monitor.socket",server,nowait \
    "${EXTRA_ARGS[@]}"
