# lib/kanidm.ps1 - Kanidm identity provider setup

function Initialize-KanidmConfig {
    param($Config)

    Write-Log "Setting up Kanidm configuration..."

    $kanidmDir = "$($Config.paths.appData)\Kanidm"
    $configSource = Join-Path (Get-ScriptRoot) "configs\kanidm-server.toml"
    $configDest = "$kanidmDir\server.toml"

    # Create directory
    if (-not (Test-Path $kanidmDir)) {
        New-Item -ItemType Directory -Path $kanidmDir -Force | Out-Null
        Write-Log "  Created Kanidm directory"
    }

    # Get domain
    $domain = Get-TailscaleDomain
    if (-not $domain) {
        Write-Log "  Cannot get Tailscale domain - Kanidm config will need manual editing" -Level Warning
        if (Test-Path $configSource) {
            Copy-Item $configSource $configDest -Force
        }
        return $false
    }

    # Copy and configure server.toml with domain replacement
    if (Test-Path $configSource) {
        $content = Get-Content $configSource -Raw
        $content = $content -replace '\{DOMAIN\}', $domain
        Set-Content -Path $configDest -Value $content -NoNewline
        Write-Log "  Kanidm config installed for $domain" -Level Success
    } else {
        Write-Log "  Kanidm config template not found at $configSource" -Level Error
        return $false
    }

    return $true
}

function Initialize-KanidmAdminAccounts {
    Write-Log "Initializing Kanidm admin accounts..."

    # Check if Kanidm is running
    $running = podman ps --filter name=kanidm --format "{{.Names}}" 2>$null
    if ($running -ne "kanidm") {
        Write-Log "  Kanidm container not running" -Level Warning
        return $false
    }

    # Recover admin account (for server configuration)
    Write-Log "  Recovering admin account..."
    $adminPass = podman exec kanidm kanidmd recover-account admin 2>&1 | Select-String "password:" | ForEach-Object { $_ -replace '.*password:\s*', '' }
    if ($adminPass) {
        Write-Log "  Admin password: $adminPass" -Level Warning
        Write-Log "  SAVE THIS PASSWORD - you'll need it for server configuration" -Level Warning
    }

    # Recover idm_admin account (for user/group management)
    Write-Log "  Recovering idm_admin account..."
    $idmAdminPass = podman exec kanidm kanidmd recover-account idm_admin 2>&1 | Select-String "password:" | ForEach-Object { $_ -replace '.*password:\s*', '' }
    if ($idmAdminPass) {
        Write-Log "  idm_admin password: $idmAdminPass" -Level Warning
        Write-Log "  SAVE THIS PASSWORD - you'll need it for user management" -Level Warning
    }

    return $true
}

function New-KanidmOAuth2Client {
    param(
        [string]$ClientName = "oauth2-proxy",
        [string]$DisplayName = "OAuth2 Proxy",
        [string]$RedirectUri
    )

    Write-Log "Creating Kanidm OAuth2 client for oauth2-proxy..."

    # Check if Kanidm is running
    $running = podman ps --filter name=kanidm --format "{{.Names}}" 2>$null
    if ($running -ne "kanidm") {
        Write-Log "  Kanidm container not running" -Level Warning
        return $null
    }

    $domain = Get-TailscaleDomain
    if (-not $domain) {
        Write-Log "  Cannot get Tailscale domain" -Level Error
        return $null
    }

    if (-not $RedirectUri) {
        $RedirectUri = "https://$domain/oauth2/callback"
    }

    try {
        # Create the OAuth2 client
        # Note: This requires authentication - user needs to run kanidm login first
        Write-Log "  Creating OAuth2 client: $ClientName"
        Write-Log "  Redirect URI: $RedirectUri"

        # Create basic secret client for oauth2-proxy
        podman exec kanidm kanidm system oauth2 create $ClientName "$DisplayName" $RedirectUri 2>&1

        # Update scope map to include openid, email, profile
        podman exec kanidm kanidm system oauth2 update-scope-map $ClientName idm_all_persons openid email profile 2>&1

        # Get the client secret
        $clientInfo = podman exec kanidm kanidm system oauth2 show-basic-secret $ClientName 2>&1
        $secret = $clientInfo | Select-String "secret:" | ForEach-Object { $_ -replace '.*secret:\s*', '' } # noqa: secret

        if ($secret) {
            Write-Log "  OAuth2 client created successfully" -Level Success
            Write-Log "  Client ID: $ClientName"
            Write-Log "  Client Secret: $secret" -Level Warning
            Write-Log "  Add this to your .env file as OAUTH2_PROXY_CLIENT_SECRET" -Level Warning
            return $secret
        } else {
            Write-Log "  Failed to get client secret - you may need to authenticate first" -Level Warning
            Write-Log "  Run: podman exec -it kanidm kanidm login -D idm_admin" -Level Info
            Write-Log "  Then: podman exec kanidm kanidm system oauth2 show-basic-secret $ClientName" -Level Info
            return $null
        }
    } catch {
        Write-Log "  Failed to create OAuth2 client: $_" -Level Error
        return $null
    }
}

function New-OAuth2ProxyCookieSecret {
    Write-Log "Generating oauth2-proxy cookie secret..."

    try {
        # Generate a 32-byte random secret and base64 encode it
        $bytes = New-Object byte[] 32
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $rng.GetBytes($bytes)
        $secret = [Convert]::ToBase64String($bytes) # noqa: secret

        Write-Log "  Cookie secret generated" -Level Success
        Write-Log "  OAUTH2_PROXY_COOKIE_SECRET=$secret" -Level Warning # noqa: secret
        Write-Log "  Add this to your .env file" -Level Warning

        return $secret
    } catch {
        Write-Log "  Failed to generate cookie secret: $_" -Level Error
        return $null
    }
}

function Show-KanidmSetupInstructions {
    param($Config)

    $domain = Get-TailscaleDomain
    if (-not $domain) { $domain = "your-tailscale-domain.ts.net" }

    Write-Host @"

================================================================================
  KANIDM SETUP INSTRUCTIONS
================================================================================

1. Start the containers:
   podman-compose up -d kanidm

2. Wait for Kanidm to initialize (check logs):
   podman logs -f kanidm

3. Recover admin accounts (save these passwords!):
   podman exec kanidm kanidmd recover-account admin
   podman exec kanidm kanidmd recover-account idm_admin

4. Access Kanidm WebUI:
   https://$($domain):8443

5. Login as idm_admin and create the oauth2-proxy client:
   podman exec -it kanidm kanidm login -D idm_admin
   podman exec kanidm kanidm system oauth2 create oauth2-proxy "OAuth2 Proxy" https://$domain/oauth2/callback
   podman exec kanidm kanidm system oauth2 update-scope-map oauth2-proxy idm_all_persons openid email profile
   podman exec kanidm kanidm system oauth2 show-basic-secret oauth2-proxy

6. Generate cookie secret:
   openssl rand -base64 32

7. Update your .env file:
   DOMAIN=$domain
   OAUTH2_PROXY_CLIENT_SECRET=<secret from step 5>  # noqa: secret
   OAUTH2_PROXY_COOKIE_SECRET=<secret from step 6>  # noqa: secret

8. Create a user account:
   podman exec -it kanidm kanidm login -D idm_admin
   podman exec kanidm kanidm person create yourname "Your Name"
   podman exec kanidm kanidm person update yourname --mail your@email.com
   podman exec kanidm kanidm person credential create-reset-token yourname

9. Start all services:
   podman-compose up -d

10. Access your services at:
    https://$domain/

================================================================================
"@ -ForegroundColor Cyan
}

function Initialize-Kanidm {
    param($Config)

    Write-Log "Initializing Kanidm identity provider..."

    # Set up config
    if (-not (Initialize-KanidmConfig -Config $Config)) {
        Write-Log "  Kanidm config setup failed" -Level Warning
    }

    # Generate cookie secret for oauth2-proxy
    $cookieSecret = New-OAuth2ProxyCookieSecret # noqa: secret
    if ($cookieSecret) {
        Write-Log "  Don't forget to add OAUTH2_PROXY_COOKIE_SECRET to your .env file" -Level Warning
    }

    # Show setup instructions
    Show-KanidmSetupInstructions -Config $Config

    Write-Log "  Kanidm initialization complete" -Level Success
    Write-Log "  Follow the instructions above to complete setup" -Level Info
}
