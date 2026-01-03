# BrowserMCP Port Proxy Setup
# Forwards localhost:9009 to Linux laptop for BrowserMCP extension
# Run as Administrator

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Enable", "Disable", "Status")]
    [string]$Action = "Status",

    [Parameter(Mandatory=$false)]
    [string]$LinuxHost = "100.103.102.77",  # snix Tailscale IP

    [Parameter(Mandatory=$false)]
    [int]$Port = 9009
)

$ErrorActionPreference = "Stop"

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ProxyStatus {
    Write-Host "`nCurrent portproxy rules:" -ForegroundColor Cyan
    $rules = netsh interface portproxy show v4tov4
    if ($rules) {
        $rules | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "  (none)"
    }

    Write-Host "`nFirewall rule status:" -ForegroundColor Cyan
    $fw = Get-NetFirewallRule -DisplayName "BrowserMCP Proxy" -ErrorAction SilentlyContinue
    if ($fw) {
        Write-Host "  BrowserMCP Proxy: $($fw.Enabled)" -ForegroundColor Green
    } else {
        Write-Host "  BrowserMCP Proxy: Not configured" -ForegroundColor Yellow
    }

    Write-Host "`nTesting connection to Linux host ($LinuxHost):$Port..." -ForegroundColor Cyan
    $test = Test-NetConnection -ComputerName $LinuxHost -Port $Port -WarningAction SilentlyContinue
    if ($test.TcpTestSucceeded) {
        Write-Host "  Connection: OK" -ForegroundColor Green
    } else {
        Write-Host "  Connection: FAILED (is BrowserMCP server running on Linux?)" -ForegroundColor Red
    }
}

function Enable-Proxy {
    Write-Host "Setting up BrowserMCP port proxy..." -ForegroundColor Cyan
    Write-Host "  Forwarding localhost:$Port -> ${LinuxHost}:$Port"

    # Remove existing rule if any
    netsh interface portproxy delete v4tov4 listenport=$Port listenaddress=127.0.0.1 2>$null

    # Add port proxy rule
    netsh interface portproxy add v4tov4 listenport=$Port listenaddress=127.0.0.1 connectport=$Port connectaddress=$LinuxHost

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Port proxy configured successfully" -ForegroundColor Green
    } else {
        Write-Host "  Failed to configure port proxy" -ForegroundColor Red
        exit 1
    }

    # Configure firewall
    $fw = Get-NetFirewallRule -DisplayName "BrowserMCP Proxy" -ErrorAction SilentlyContinue
    if (-not $fw) {
        Write-Host "  Creating firewall rule..."
        New-NetFirewallRule -DisplayName "BrowserMCP Proxy" `
            -Direction Inbound `
            -Protocol TCP `
            -LocalPort $Port `
            -Action Allow `
            -Profile Private,Domain | Out-Null
        Write-Host "  Firewall rule created" -ForegroundColor Green
    } else {
        Enable-NetFirewallRule -DisplayName "BrowserMCP Proxy"
        Write-Host "  Firewall rule enabled" -ForegroundColor Green
    }

    Write-Host "`nBrowserMCP proxy is now active!" -ForegroundColor Green
    Write-Host "Chrome extension will connect to localhost:$Port -> ${LinuxHost}:$Port"
}

function Disable-Proxy {
    Write-Host "Disabling BrowserMCP port proxy..." -ForegroundColor Cyan

    # Remove port proxy
    netsh interface portproxy delete v4tov4 listenport=$Port listenaddress=127.0.0.1 2>$null
    Write-Host "  Port proxy removed" -ForegroundColor Green

    # Disable firewall rule
    $fw = Get-NetFirewallRule -DisplayName "BrowserMCP Proxy" -ErrorAction SilentlyContinue
    if ($fw) {
        Disable-NetFirewallRule -DisplayName "BrowserMCP Proxy"
        Write-Host "  Firewall rule disabled" -ForegroundColor Green
    }

    Write-Host "`nBrowserMCP proxy disabled" -ForegroundColor Yellow
}

# Main
if (-not (Test-Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    exit 1
}

switch ($Action) {
    "Enable"  { Enable-Proxy }
    "Disable" { Disable-Proxy }
    "Status"  { Get-ProxyStatus }
}
