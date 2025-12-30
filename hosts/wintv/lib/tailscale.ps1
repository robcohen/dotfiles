# lib/tailscale.ps1 - Tailscale configuration

function Get-TailscaleExecutable {
    $tailscale = Get-Command "tailscale" -ErrorAction SilentlyContinue
    if ($tailscale) {
        return $tailscale.Source
    }

    $tailscalePath = "${env:ProgramFiles}\Tailscale\tailscale.exe"
    if (Test-Path $tailscalePath) {
        return $tailscalePath
    }

    return $null
}

function Set-TailscaleConfiguration {
    Write-Log "Configuring Tailscale..."

    $tailscale = Get-TailscaleExecutable
    if (-not $tailscale) {
        Write-Log "  Tailscale not found - will configure after reboot" -Level Warning
        return
    }

    # Check if already logged in
    $status = & $tailscale status 2>&1
    if ($status -match "Logged out") {
        Write-Log "  Tailscale installed but not logged in" -Level Warning
        Write-Log "  Run 'tailscale login' after setup completes" -Level Info
        return
    }

    # Configure tags for Mullvad access
    Write-Log "  Setting Tailscale tags..."
    try {
        & $tailscale set --advertise-tags=tag:personal,tag:mullvad 2>&1 | Out-Null
        Write-Log "  Tags configured: tag:personal, tag:mullvad" -Level Success
    } catch {
        Write-Log "  Failed to set tags (may need admin approval): $_" -Level Warning
    }

    Write-Log "  Tailscale configured" -Level Success
}

function New-TailscaleHelperScripts {
    param($Config)

    Write-Log "Creating Tailscale helper scripts..."

    $scriptsPath = "$($Config.paths.appData)\Tailscale"
    if (-not (Test-Path $scriptsPath)) {
        New-Item -ItemType Directory -Path $scriptsPath -Force | Out-Null
    }

    # mullvad-connect.ps1
    $connectScript = @'
# List and connect to Mullvad exit nodes
param(
    [string]$Country,
    [string]$City
)

$tailscale = "${env:ProgramFiles}\Tailscale\tailscale.exe"

Write-Host "Available Mullvad exit nodes:" -ForegroundColor Cyan
& $tailscale exit-node list | Where-Object { $_ -match "mullvad" }

if ($Country) {
    $nodes = & $tailscale exit-node list | Where-Object { $_ -match "mullvad" -and $_ -match $Country }
    if ($City) {
        $nodes = $nodes | Where-Object { $_ -match $City }
    }

    $node = ($nodes | Select-Object -First 1) -split '\s+' | Select-Object -First 1
    if ($node) {
        Write-Host "`nConnecting to: $node" -ForegroundColor Green
        & $tailscale set --exit-node=$node --exit-node-allow-lan-access=true
    } else {
        Write-Host "No matching node found" -ForegroundColor Red
    }
}
'@

    $connectScript | Out-File "$scriptsPath\mullvad-connect.ps1" -Encoding UTF8
    Write-Log "  Created: $scriptsPath\mullvad-connect.ps1" -Level Success

    # mullvad-disconnect.ps1
    $disconnectScript = @'
# Disconnect from Mullvad exit node
$tailscale = "${env:ProgramFiles}\Tailscale\tailscale.exe"
& $tailscale set --exit-node=
Write-Host "Disconnected from Mullvad exit node" -ForegroundColor Green
'@

    $disconnectScript | Out-File "$scriptsPath\mullvad-disconnect.ps1" -Encoding UTF8
    Write-Log "  Created: $scriptsPath\mullvad-disconnect.ps1" -Level Success

    # mullvad-status.ps1
    $statusScript = @'
# Check Mullvad/Tailscale status and DNS leaks
$tailscale = "${env:ProgramFiles}\Tailscale\tailscale.exe"

Write-Host "=== Tailscale Status ===" -ForegroundColor Cyan
& $tailscale status

Write-Host "`n=== Exit Node ===" -ForegroundColor Cyan
$exitNode = & $tailscale status --json | ConvertFrom-Json | Select-Object -ExpandProperty ExitNodeStatus -ErrorAction SilentlyContinue
if ($exitNode) {
    Write-Host "Connected to: $($exitNode.TailscaleIPs)" -ForegroundColor Green
} else {
    Write-Host "No exit node active" -ForegroundColor Yellow
}

Write-Host "`n=== DNS Leak Test ===" -ForegroundColor Cyan
try {
    $result = Invoke-RestMethod -Uri "https://am.i.mullvad.net/json" -TimeoutSec 10
    if ($result.mullvad_exit_ip) {
        Write-Host "PROTECTED via Mullvad" -ForegroundColor Green
        Write-Host "  Exit: $($result.mullvad_exit_ip_hostname)"
        Write-Host "  Location: $($result.city), $($result.country)"
        Write-Host "  IP: $($result.ip)"
    } else {
        Write-Host "NOT PROTECTED - Traffic not going through Mullvad!" -ForegroundColor Red
        Write-Host "  IP: $($result.ip)"
        Write-Host "  Location: $($result.city), $($result.country)"
    }
} catch {
    Write-Host "Could not check Mullvad status: $_" -ForegroundColor Red
}
'@

    $statusScript | Out-File "$scriptsPath\mullvad-status.ps1" -Encoding UTF8
    Write-Log "  Created: $scriptsPath\mullvad-status.ps1" -Level Success

    Write-Log "  Helper scripts created in $scriptsPath" -Level Success
}
