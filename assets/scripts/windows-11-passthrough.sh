#!/usr/bin/env bash

# Dynamic path resolution for NixOS
SWTPM=$(nix-build '<nixpkgs>' -A swtpm --no-out-link 2>/dev/null)/bin/swtpm
QEMU=$(which qemu-system-x86_64)
OVMF_CODE=$(ls -d /nix/store/*OVMF*/FV/OVMF_CODE.fd 2>/dev/null | head -1)

# VM Directory - use SUDO_USER if running with sudo
if [ -n "$SUDO_USER" ]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    USER_HOME="$HOME"
fi
VM_DIR="$USER_HOME/VMs/windows-11"
cd "$VM_DIR" || { echo "Error: VM directory $VM_DIR not found. Run quickget windows 11 first."; exit 1; }

# ISO files from quickemu
WIN_ISO="$VM_DIR/Win11_25H2_EnglishInternational_x64.iso"
VIRTIO_ISO="$VM_DIR/virtio-win.iso"
UNATTENDED_ISO="$VM_DIR/unattended.iso"

# Create OVMF_VARS.fd if it doesn't exist
if [ ! -f "OVMF_VARS.fd" ]; then
    OVMF_VARS_TEMPLATE=$(ls -d /nix/store/*OVMF*/FV/OVMF_VARS.fd 2>/dev/null | head -1)
    cp "$OVMF_VARS_TEMPLATE" "OVMF_VARS.fd"
    chmod 644 "OVMF_VARS.fd"
fi

# Create disk image if it doesn't exist
if [ ! -f "disk.qcow2" ]; then
    qemu-img create -f qcow2 disk.qcow2 128G
fi

# Start TPM emulator
$SWTPM socket \
    --ctrl type=unixio,path="$VM_DIR/windows-11.swtpm-sock" \
    --terminate \
    --tpmstate dir="$VM_DIR" \
    --tpm2 &

# Start QEMU with GPU passthrough
$QEMU \
    -name windows-11,process=windows-11 \
    -pidfile "$VM_DIR/windows-11.pid" \
    -enable-kvm \
    -machine q35,smm=on,vmport=off,hpet=off \
    -global kvm-pit.lost_tick_policy=discard \
    -global ICH9-LPC.disable_s3=1 \
    -cpu host,kvm=off,+hypervisor,+invtsc,l3-cache=on,migratable=no,hv_passthrough,host-phys-bits=off \
    -smp cores=8,threads=2,sockets=1 \
    -m 8G \
    -vga none \
    -device vfio-pci,host=01:00.0,multifunction=on \
    -device vfio-pci,host=01:00.1 \
    -display sdl \
    -device intel-hda \
    -rtc base=localtime,clock=host,driftfix=slew \
    -device virtio-rng-pci,rng=rng0 \
    -object rng-random,id=rng0,filename=/dev/urandom \
    -device qemu-xhci,id=spicepass \
    -device pci-ohci,id=smartpass \
    -device usb-ccid \
    -chardev spicevmc,id=ccid,name=smartcard \
    -device ccid-card-passthru,chardev=ccid \
    -device usb-ehci,id=input \
    -k en-us \
    -device virtio-net,netdev=nic \
    -netdev user,hostname=windows-11,hostfwd=tcp::22221-:22,id=nic \
    -global driver=cfi.pflash01,property=secure,value=on \
    -drive if=pflash,format=raw,unit=0,file="$OVMF_CODE",readonly=on \
    -drive if=pflash,format=raw,unit=1,file="$VM_DIR/OVMF_VARS.fd" \
    -drive media=cdrom,index=0,file="$WIN_ISO" \
    -drive media=cdrom,index=1,file="$VIRTIO_ISO" \
    -drive media=cdrom,index=2,file="$UNATTENDED_ISO" \
    -device virtio-blk-pci,drive=SystemDisk \
    -drive id=SystemDisk,if=none,format=qcow2,file="$VM_DIR/disk.qcow2" \
    -drive if=none,id=usbdisk,format=raw,file=/dev/sda \
    -device usb-storage,drive=usbdisk \
    -chardev socket,id=chrtpm,path="$VM_DIR/windows-11.swtpm-sock" \
    -tpmdev emulator,id=tpm0,chardev=chrtpm \
    -device tpm-tis,tpmdev=tpm0 \
    -serial unix:"$VM_DIR/windows-11-serial.socket",server,nowait \
    -monitor unix:"$VM_DIR/windows-11-monitor.socket",server,nowait \
    -spice port=5900,addr=127.0.0.1,disable-ticketing=on \
    -device ivshmem-plain,id=shmem0,memdev=looking-glass \
    -object memory-backend-file,id=looking-glass,mem-path=/dev/kvmfr0,size=128M,share=yes \
    -object input-linux,id=kbd1,evdev=/dev/input/event3,grab_all=on,repeat=on \
    -object input-linux,id=mouse1,evdev=/dev/input/event2
