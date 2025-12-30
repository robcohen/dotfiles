# lib/gpu.ps1 - NVIDIA GPU configuration for containers

function Test-NvidiaGpuAvailable {
    Write-Log "Checking for NVIDIA GPU..."

    try {
        $gpu = & nvidia-smi --query-gpu=name --format=csv,noheader 2>&1
        if ($LASTEXITCODE -eq 0 -and $gpu) {
            Write-Log "  Found: $gpu" -Level Success
            return $true
        }
    } catch {}

    Write-Log "  NVIDIA GPU not detected" -Level Warning
    return $false
}

function Install-NvidiaContainerToolkit {
    Write-Log "Installing NVIDIA Container Toolkit in Podman machine..."

    # Check if already installed
    $check = podman machine ssh "command -v nvidia-ctk" 2>&1
    if ($check -match "nvidia-ctk") {
        Write-Log "  NVIDIA Container Toolkit already installed" -Level Success
        return $true
    }

    try {
        # Install nvidia-container-toolkit in Fedora-based Podman machine
        Write-Log "  Adding NVIDIA repository..."
        podman machine ssh "curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo > /dev/null" 2>&1

        Write-Log "  Installing nvidia-container-toolkit..."
        podman machine ssh "sudo dnf install -y nvidia-container-toolkit" 2>&1

        Write-Log "  Generating CDI specification..."
        podman machine ssh "sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml" 2>&1

        Write-Log "  NVIDIA Container Toolkit installed" -Level Success
        return $true
    } catch {
        Write-Log "  Failed to install NVIDIA Container Toolkit: $_" -Level Error
        return $false
    }
}

function Set-PrivilegedPortAccess {
    Write-Log "Configuring privileged port access..."

    try {
        # Allow unprivileged users to bind to ports < 1024
        podman machine ssh "sudo sysctl -w net.ipv4.ip_unprivileged_port_start=0" 2>&1
        podman machine ssh "echo 'net.ipv4.ip_unprivileged_port_start=0' | sudo tee /etc/sysctl.d/99-unprivileged-ports.conf" 2>&1

        Write-Log "  Privileged port access configured" -Level Success
        return $true
    } catch {
        Write-Log "  Failed to configure privileged port access: $_" -Level Warning
        return $false
    }
}

function Initialize-GpuSupport {
    param($Config)

    Write-Log "Initializing GPU support..."

    if (-not (Test-NvidiaGpuAvailable)) {
        Write-Log "  Skipping GPU setup - no NVIDIA GPU found" -Level Warning
        return $false
    }

    Install-NvidiaContainerToolkit
    Set-PrivilegedPortAccess

    Write-Log "  GPU support initialized" -Level Success
    return $true
}
