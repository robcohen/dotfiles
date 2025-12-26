# lib/packages.ps1 - Package management via winget

function Test-PackageInstalled {
    param([string]$PackageId)

    $result = winget list --id $PackageId --accept-source-agreements 2>&1
    return $result -match $PackageId
}

function Install-Packages {
    param([array]$Packages)

    Write-Log "Installing packages..."

    # Update winget sources
    Write-Log "  Updating package sources..."
    winget source update 2>&1 | Out-Null

    foreach ($package in $Packages) {
        if (Test-PackageInstalled -PackageId $package) {
            Write-Log "  $package already installed" -Level Success
        } else {
            Write-Log "  Installing $package..."
            try {
                $result = winget install --id $package --accept-source-agreements --accept-package-agreements -h 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "  $package installed" -Level Success
                } else {
                    Write-Log "  $package installation returned: $result" -Level Warning
                }
            } catch {
                Write-Log "  Failed to install $package : $_" -Level Error
            }
        }
    }
}

function Install-PythonAndPodmanCompose {
    Write-Log "Installing Python and podman-compose..."

    # Check if Python is installed
    $pythonPath = "C:\Users\$env:USERNAME\AppData\Local\Programs\Python\Python312\python.exe"
    if (-not (Test-Path $pythonPath)) {
        Write-Log "  Installing Python 3.12..."
        winget install --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements -h 2>&1 | Out-Null

        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    }

    # Check if podman-compose is installed
    $podmanComposePath = "C:\Users\$env:USERNAME\AppData\Local\Programs\Python\Python312\Scripts\podman-compose.exe"
    if (-not (Test-Path $podmanComposePath)) {
        Write-Log "  Installing podman-compose..."
        & $pythonPath -m pip install podman-compose 2>&1 | Out-Null
        Write-Log "  podman-compose installed" -Level Success
    } else {
        Write-Log "  podman-compose already installed" -Level Success
    }
}
