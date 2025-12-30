# lib/vm.ps1 - Hyper-V VM creation

function New-VMCreationScript {
    param($Config)

    Write-Log "Creating VM setup script..."

    $vmPath = "$($Config.paths.vms)"
    $scriptPath = "$vmPath\create-vm.ps1"

    if (-not (Test-Path $vmPath)) {
        New-Item -ItemType Directory -Path $vmPath -Force | Out-Null
    }

    $vmScript = @"
# Run this after downloading NixOS ISO
# Download: nix build .#nixtv-player-iso

#Requires -RunAsAdministrator

`$VMName = "wintv-vm"
`$VMPath = "$vmPath"
`$ISOPath = "`$VMPath\nixos.iso"  # Copy ISO here
`$VHDPath = "`$VMPath\wintv-vm.vhdx"
`$MemoryGB = 8
`$CPUCount = 4
`$DiskGB = 100

# Check if VM already exists
if (Get-VM -Name `$VMName -ErrorAction SilentlyContinue) {
    Write-Host "VM '`$VMName' already exists" -ForegroundColor Yellow
    `$response = Read-Host "Delete and recreate? (y/N)"
    if (`$response -eq 'y') {
        Stop-VM -Name `$VMName -Force -ErrorAction SilentlyContinue
        Remove-VM -Name `$VMName -Force
        Remove-Item `$VHDPath -Force -ErrorAction SilentlyContinue
    } else {
        exit 0
    }
}

# Check ISO exists
if (-not (Test-Path `$ISOPath)) {
    Write-Host "ERROR: ISO not found at `$ISOPath" -ForegroundColor Red
    Write-Host "Build ISO with: nix build .#nixtv-player-iso"
    Write-Host "Then copy to: `$ISOPath"
    exit 1
}

Write-Host "Creating VM '`$VMName'..." -ForegroundColor Cyan

# Create VM
New-VM -Name `$VMName -Path `$VMPath -MemoryStartupBytes (`$MemoryGB * 1GB) -Generation 2

# Configure CPU
Set-VMProcessor -VMName `$VMName -Count `$CPUCount

# Create and attach disk
New-VHD -Path `$VHDPath -SizeBytes (`$DiskGB * 1GB) -Dynamic
Add-VMHardDiskDrive -VMName `$VMName -Path `$VHDPath

# Attach ISO
Add-VMDvdDrive -VMName `$VMName -Path `$ISOPath

# Configure boot order (DVD first for install)
`$dvd = Get-VMDvdDrive -VMName `$VMName
Set-VMFirmware -VMName `$VMName -FirstBootDevice `$dvd

# Network - Default Switch for internet access
Connect-VMNetworkAdapter -VMName `$VMName -SwitchName "Default Switch"

# Disable Secure Boot (for NixOS)
Set-VMFirmware -VMName `$VMName -EnableSecureBoot Off

# Enable nested virtualization (optional, for containers in VM)
Set-VMProcessor -VMName `$VMName -ExposeVirtualizationExtensions `$true

# Dynamic memory
Set-VMMemory -VMName `$VMName -DynamicMemoryEnabled `$true -MinimumBytes 2GB -MaximumBytes (`$MemoryGB * 1GB)

# Enable checkpoints
Set-VM -VMName `$VMName -CheckpointType Production

Write-Host "`nVM '`$VMName' created successfully!" -ForegroundColor Green
Write-Host "`nNext steps:"
Write-Host "  1. Start-VM -Name `$VMName"
Write-Host "  2. vmconnect localhost `$VMName"
Write-Host "  3. Install NixOS from the ISO"
Write-Host "  4. After install, remove ISO: Remove-VMDvdDrive -VMName `$VMName"
"@

    $vmScript | Out-File -FilePath $scriptPath -Encoding UTF8
    Write-Log "  Created: $scriptPath" -Level Success
}
