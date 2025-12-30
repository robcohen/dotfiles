# hosts/wintv/bootstrap-remote.ps1
# Bootstrap script to enable WinRM/PSRemoting
#
# Run this LOCALLY on the Windows machine first (as Administrator):
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   .\bootstrap-remote.ps1
#
# Then from another Windows machine or PowerShell:
#   Enter-PSSession -ComputerName <hostname> -Credential (Get-Credential)
#
# From NixOS (using Python pywinrm or similar):
#   See instructions at end of script

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host @"

    ╔══════════════════════════════════════════════════════════════╗
    ║  Windows Remote Management (WinRM) Bootstrap                  ║
    ╚══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# ===========================================================================
# Enable PSRemoting
# ===========================================================================
Write-Host "[1/6] Enabling PowerShell Remoting..." -ForegroundColor Yellow

try {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    Write-Host "  PSRemoting enabled" -ForegroundColor Green
} catch {
    Write-Host "  PSRemoting may already be enabled: $_" -ForegroundColor Yellow
}

# ===========================================================================
# Configure WinRM Service
# ===========================================================================
Write-Host "`n[2/6] Configuring WinRM Service..." -ForegroundColor Yellow

# Start and set to automatic
Set-Service -Name WinRM -StartupType Automatic
Start-Service WinRM
Write-Host "  WinRM service started and set to automatic" -ForegroundColor Green

# Configure WinRM settings
$winrmResult = winrm quickconfig -quiet 2>&1
if ($LASTEXITCODE -ne 0 -and $winrmResult -notmatch "already running") {
    Write-Host "  WinRM quickconfig warning: $winrmResult" -ForegroundColor Yellow
} else {
    Write-Host "  WinRM quickconfig applied" -ForegroundColor Green
}

# ===========================================================================
# Configure TrustedHosts (for non-domain environments)
# ===========================================================================
Write-Host "`n[3/6] Configuring TrustedHosts..." -ForegroundColor Yellow

# Allow connections from Tailscale network (100.x.x.x) and local network
$trustedHosts = "100.*,192.168.*,10.*,*.internal"
Set-Item WSMan:\localhost\Client\TrustedHosts -Value $trustedHosts -Force
Write-Host "  TrustedHosts: $trustedHosts" -ForegroundColor Green

# ===========================================================================
# Configure HTTPS Listener (more secure)
# ===========================================================================
Write-Host "`n[4/6] Configuring WinRM Listeners..." -ForegroundColor Yellow

# Check existing listeners
$httpListener = Get-WSManInstance -ResourceURI winrm/config/Listener -Enumerate |
    Where-Object { $_.Transport -eq "HTTP" }

if ($httpListener) {
    Write-Host "  HTTP listener already configured on port 5985" -ForegroundColor Green
} else {
    $listenerResult = New-WSManInstance -ResourceURI winrm/config/Listener -SelectorSet @{Address="*"; Transport="HTTP"} 2>&1
    if ($listenerResult -is [System.Management.Automation.ErrorRecord]) {
        Write-Host "  HTTP listener creation failed: $listenerResult" -ForegroundColor Yellow
    } else {
        Write-Host "  HTTP listener created on port 5985" -ForegroundColor Green
    }
}

# For HTTPS, we'd need a certificate - skip for now but note it
Write-Host "  Note: For production, configure HTTPS listener with certificate" -ForegroundColor Yellow

# ===========================================================================
# Configure Firewall
# ===========================================================================
Write-Host "`n[5/6] Configuring Firewall..." -ForegroundColor Yellow

# WinRM HTTP (5985)
$httpRule = Get-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -ErrorAction SilentlyContinue
if (-not $httpRule) {
    New-NetFirewallRule -Name "WINRM-HTTP-In-TCP" `
        -DisplayName "Windows Remote Management (HTTP-In)" `
        -Enabled True -Direction Inbound -Protocol TCP `
        -Action Allow -LocalPort 5985 `
        -Profile Private,Domain | Out-Null
    Write-Host "  Firewall rule created for WinRM (TCP 5985)" -ForegroundColor Green
} else {
    Enable-NetFirewallRule -Name "WINRM-HTTP-In-TCP"
    Write-Host "  Firewall rule enabled for WinRM" -ForegroundColor Green
}

# Also enable predefined Windows Remote Management rules
Enable-NetFirewallRule -DisplayGroup "Windows Remote Management" -ErrorAction SilentlyContinue
Write-Host "  Windows Remote Management firewall group enabled" -ForegroundColor Green

# ===========================================================================
# Install Tailscale
# ===========================================================================
Write-Host "`n[6/6] Installing Tailscale..." -ForegroundColor Yellow

$tailscale = Get-Command "tailscale" -ErrorAction SilentlyContinue
if (-not $tailscale -and -not (Test-Path "${env:ProgramFiles}\Tailscale\tailscale.exe")) {
    Write-Host "  Installing Tailscale via WinGet..."
    try {
        winget install --id Tailscale.Tailscale --accept-source-agreements --accept-package-agreements -h
        Write-Host "  Tailscale installed - run 'tailscale login' to authenticate" -ForegroundColor Green
    } catch {
        Write-Host "  WinGet failed. Install manually: https://tailscale.com/download/windows" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Tailscale already installed" -ForegroundColor Green
}

# ===========================================================================
# Test Configuration
# ===========================================================================
Write-Host "`n[Test] Verifying WinRM configuration..." -ForegroundColor Yellow

$testResult = Test-WSMan -ComputerName localhost -ErrorAction SilentlyContinue
if ($testResult) {
    Write-Host "  WinRM is responding correctly" -ForegroundColor Green
} else {
    Write-Host "  WinRM test failed - check configuration" -ForegroundColor Red
}

# ===========================================================================
# Summary
# ===========================================================================
$hostname = $env:COMPUTERNAME
$fqdn = [System.Net.Dns]::GetHostEntry($env:COMPUTERNAME).HostName
$ipAddresses = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.InterfaceAlias -notmatch "Loopback" -and $_.IPAddress -notmatch "^169" }).IPAddress
$currentUser = $env:USERNAME

Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║  WINRM BOOTSTRAP COMPLETE                                     ║
╚══════════════════════════════════════════════════════════════╝

Hostname: $hostname
IP Addresses: $($ipAddresses -join ', ')

"@ -ForegroundColor Green

Write-Host "CONNECT FROM WINDOWS:" -ForegroundColor Cyan
Write-Host @"
  # Interactive session
  `$cred = Get-Credential $currentUser
  Enter-PSSession -ComputerName $hostname -Credential `$cred

  # Run a command
  Invoke-Command -ComputerName $hostname -Credential `$cred -ScriptBlock {
      # Your commands here
      Get-Process
  }

  # Run setup.ps1 remotely
  Invoke-Command -ComputerName $hostname -Credential `$cred -FilePath .\setup.ps1

"@

Write-Host "CONNECT FROM NIXOS:" -ForegroundColor Cyan
Write-Host @"
  # Option 1: Use pywinrm (Python)
  nix-shell -p python3 python3Packages.pywinrm

  python3 << 'EOF'
  import winrm
  s = winrm.Session('$($ipAddresses[0])', auth=('$currentUser', 'YOUR_PASSWORD'))
  r = s.run_ps('Get-Process | Select -First 5')
  print(r.std_out.decode())
  EOF

  # Option 2: Use evil-winrm (for penetration testing, also works for admin)
  nix-shell -p evil-winrm
  evil-winrm -i $($ipAddresses[0]) -u $currentUser -p 'YOUR_PASSWORD'

  # Option 3: Use Ansible with pywinrm
  # See: https://docs.ansible.com/ansible/latest/os_guide/windows_winrm.html

"@

Write-Host "VIA TAILSCALE:" -ForegroundColor Cyan
Write-Host @"
  After running 'tailscale login' on this machine:
  - Connect using Tailscale hostname: $hostname
  - Or use Tailscale IP (check with: tailscale ip -4)

"@

Write-Host "SECURITY NOTES:" -ForegroundColor Yellow
Write-Host @"
  - WinRM is configured for HTTP (port 5985)
  - For production, configure HTTPS with a certificate
  - Connections are limited to Private/Domain network profiles
  - TrustedHosts allows: $trustedHosts

"@
