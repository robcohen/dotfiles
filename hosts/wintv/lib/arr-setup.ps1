# =============================================================================
# Arr Stack Setup - API-based configuration
# =============================================================================
# Configures service connections after containers start:
#   - Prowlarr → Radarr, Sonarr, Lidarr, Readarr (indexer sync)
#   - Radarr/Sonarr/Lidarr/Readarr → qBittorrent (download client)
#   - Root folders for each service
#   - Jellyfin user accounts

# =============================================================================
# Service Health Checks
# =============================================================================

function Wait-ForService {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,

        [Parameter(Mandatory=$true)]
        [string]$Name,

        [int]$TimeoutSeconds = 120,
        [int]$IntervalSeconds = 5
    )

    $elapsed = 0
    Write-Host "  Waiting for $Name..." -ForegroundColor Yellow -NoNewline

    while ($elapsed -lt $TimeoutSeconds) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Write-Host " Ready!" -ForegroundColor Green
                return $true
            }
        } catch {
            # Service not ready yet
        }

        Start-Sleep -Seconds $IntervalSeconds
        $elapsed += $IntervalSeconds
        Write-Host "." -NoNewline
    }

    Write-Host " TIMEOUT!" -ForegroundColor Red
    return $false
}

# =============================================================================
# Prowlarr API Functions
# =============================================================================

function Add-ProwlarrApplication {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProwlarrUrl,

        [Parameter(Mandatory=$true)]
        [string]$ProwlarrApiKey,

        [Parameter(Mandatory=$true)]
        [string]$AppName,

        [Parameter(Mandatory=$true)]
        [string]$AppUrl,

        [Parameter(Mandatory=$true)]
        [string]$AppApiKey,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Radarr", "Sonarr", "Lidarr", "Readarr")]
        [string]$AppType
    )

    $headers = @{
        "X-Api-Key" = $ProwlarrApiKey
        "Content-Type" = "application/json"
    }

    # Check if app already exists
    try {
        $existing = Invoke-RestMethod -Uri "$ProwlarrUrl/api/v1/applications" -Headers $headers -Method Get
        if ($existing | Where-Object { $_.name -eq $AppName }) {
            Write-Host "    $AppName already configured in Prowlarr" -ForegroundColor Yellow
            return
        }
    } catch {
        Write-Host "    WARNING: Could not check existing apps: $_" -ForegroundColor Yellow
    }

    $body = @{
        name = $AppName
        syncLevel = "fullSync"
        implementationName = $AppType
        implementation = $AppType
        configContract = "${AppType}Settings"
        fields = @(
            @{ name = "prowlarrUrl"; value = "http://localhost:9696" }
            @{ name = "baseUrl"; value = $AppUrl }
            @{ name = "apiKey"; value = $AppApiKey }
            @{ name = "syncCategories"; value = @(2000, 2010, 2020, 2030, 2040, 2045, 2050, 2060) }
        )
        tags = @()
    } | ConvertTo-Json -Depth 10

    try {
        Invoke-RestMethod -Uri "$ProwlarrUrl/api/v1/applications" -Headers $headers -Method Post -Body $body | Out-Null
        Write-Host "    Added $AppName to Prowlarr" -ForegroundColor Green
    } catch {
        Write-Host "    ERROR adding $AppName to Prowlarr: $_" -ForegroundColor Red
    }
}

# =============================================================================
# Download Client Configuration
# =============================================================================

function Add-DownloadClient {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServiceUrl,

        [Parameter(Mandatory=$true)]
        [string]$ApiKey,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Radarr", "Sonarr", "Lidarr", "Readarr")]
        [string]$ServiceType,

        [string]$QBitHost = "localhost",
        [int]$QBitPort = 8080,
        [string]$QBitUser = "admin",
        [string]$QBitPassword = ""
    )

    $headers = @{
        "X-Api-Key" = $ApiKey
        "Content-Type" = "application/json"
    }

    $apiVersion = if ($ServiceType -eq "Sonarr") { "v3" } else { "v3" }

    # Check if download client already exists
    try {
        $existing = Invoke-RestMethod -Uri "$ServiceUrl/api/$apiVersion/downloadclient" -Headers $headers -Method Get
        if ($existing | Where-Object { $_.name -eq "qBittorrent" }) {
            Write-Host "    qBittorrent already configured in $ServiceType" -ForegroundColor Yellow
            return
        }
    } catch {
        Write-Host "    WARNING: Could not check existing clients: $_" -ForegroundColor Yellow
    }

    # Category based on service type
    $category = switch ($ServiceType) {
        "Radarr" { "movies" }
        "Sonarr" { "tv" }
        "Lidarr" { "music" }
        "Readarr" { "books" }
    }

    $body = @{
        name = "qBittorrent"
        enable = $true
        protocol = "torrent"
        priority = 1
        implementation = "QBittorrent"
        configContract = "QBittorrentSettings"
        fields = @(
            @{ name = "host"; value = $QBitHost }
            @{ name = "port"; value = $QBitPort }
            @{ name = "useSsl"; value = $false }
            @{ name = "username"; value = $QBitUser }
            @{ name = "password"; value = $QBitPassword }
            @{ name = "movieCategory"; value = $category }
            @{ name = "tvCategory"; value = $category }
            @{ name = "musicCategory"; value = $category }
            @{ name = "recentMoviePriority"; value = 0 }
            @{ name = "recentTvPriority"; value = 0 }
            @{ name = "olderMoviePriority"; value = 0 }
            @{ name = "olderTvPriority"; value = 0 }
            @{ name = "initialState"; value = 0 }
            @{ name = "sequentialOrder"; value = $false }
            @{ name = "firstAndLast"; value = $false }
        )
        tags = @()
    } | ConvertTo-Json -Depth 10

    try {
        Invoke-RestMethod -Uri "$ServiceUrl/api/$apiVersion/downloadclient" -Headers $headers -Method Post -Body $body | Out-Null
        Write-Host "    Added qBittorrent to $ServiceType" -ForegroundColor Green
    } catch {
        Write-Host "    ERROR adding qBittorrent to $ServiceType`: $_" -ForegroundColor Red
    }
}

# =============================================================================
# Root Folder Configuration
# =============================================================================

function Add-RootFolder {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServiceUrl,

        [Parameter(Mandatory=$true)]
        [string]$ApiKey,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Radarr", "Sonarr", "Lidarr", "Readarr")]
        [string]$ServiceType,

        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $headers = @{
        "X-Api-Key" = $ApiKey
        "Content-Type" = "application/json"
    }

    $apiVersion = "v3"

    # Check if root folder already exists
    try {
        $existing = Invoke-RestMethod -Uri "$ServiceUrl/api/$apiVersion/rootfolder" -Headers $headers -Method Get
        if ($existing | Where-Object { $_.path -eq $Path }) {
            Write-Host "    Root folder already configured in $ServiceType" -ForegroundColor Yellow
            return
        }
    } catch {
        Write-Host "    WARNING: Could not check existing root folders: $_" -ForegroundColor Yellow
    }

    $body = @{
        path = $Path
    } | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri "$ServiceUrl/api/$apiVersion/rootfolder" -Headers $headers -Method Post -Body $body | Out-Null
        Write-Host "    Added root folder $Path to $ServiceType" -ForegroundColor Green
    } catch {
        Write-Host "    ERROR adding root folder to $ServiceType`: $_" -ForegroundColor Red
    }
}

# =============================================================================
# Jellyfin User Setup
# =============================================================================

function Initialize-JellyfinUsers {
    param(
        [Parameter(Mandatory=$true)]
        [string]$JellyfinUrl,

        [Parameter(Mandatory=$true)]
        [string]$AdminPassword,

        [string]$RegularUser = "user",
        [string]$RegularPassword = "user"
    )

    Write-Host "  Configuring Jellyfin users..." -ForegroundColor Yellow

    # First, we need to complete the startup wizard via API
    try {
        # Check if startup wizard is complete
        $config = Invoke-RestMethod -Uri "$JellyfinUrl/System/Configuration" -Method Get -UseBasicParsing -ErrorAction Stop
        Write-Host "    Jellyfin already configured" -ForegroundColor Yellow
        return
    } catch {
        # Wizard not complete, proceed with setup
    }

    # Get startup config
    try {
        $startupConfig = Invoke-RestMethod -Uri "$JellyfinUrl/Startup/Configuration" -Method Get -UseBasicParsing
    } catch {
        Write-Host "    ERROR: Could not get startup configuration" -ForegroundColor Red
        return
    }

    # Complete startup wizard
    try {
        # Set preferred metadata language
        $langBody = @{
            UICulture = "en-US"
            MetadataCountryCode = "US"
            PreferredMetadataLanguage = "en"
        } | ConvertTo-Json

        Invoke-RestMethod -Uri "$JellyfinUrl/Startup/Configuration" -Method Post -Body $langBody -ContentType "application/json" | Out-Null

        # Create admin user
        $adminBody = @{
            Name = "admin"
            Password = $AdminPassword
        } | ConvertTo-Json

        Invoke-RestMethod -Uri "$JellyfinUrl/Startup/User" -Method Post -Body $adminBody -ContentType "application/json" | Out-Null
        Write-Host "    Created admin user" -ForegroundColor Green

        # Complete startup wizard
        Invoke-RestMethod -Uri "$JellyfinUrl/Startup/Complete" -Method Post | Out-Null
        Write-Host "    Startup wizard completed" -ForegroundColor Green

    } catch {
        Write-Host "    ERROR during Jellyfin setup: $_" -ForegroundColor Red
        return
    }

    # Authenticate as admin to create regular user
    try {
        $authBody = @{
            Username = "admin"
            Pw = $AdminPassword
        } | ConvertTo-Json

        $authHeaders = @{
            "X-Emby-Authorization" = 'MediaBrowser Client="WinTV Setup", Device="PowerShell", DeviceId="wintv-setup", Version="1.0"'
        }

        $authResponse = Invoke-RestMethod -Uri "$JellyfinUrl/Users/AuthenticateByName" -Method Post -Body $authBody -ContentType "application/json" -Headers $authHeaders
        $accessToken = $authResponse.AccessToken

        # Create regular user
        $userHeaders = @{
            "X-Emby-Authorization" = "MediaBrowser Client=`"WinTV Setup`", Device=`"PowerShell`", DeviceId=`"wintv-setup`", Version=`"1.0`", Token=`"$accessToken`""
        }

        $userBody = @{
            Name = $RegularUser
            Password = $RegularPassword
        } | ConvertTo-Json

        Invoke-RestMethod -Uri "$JellyfinUrl/Users/New" -Method Post -Body $userBody -ContentType "application/json" -Headers $userHeaders | Out-Null
        Write-Host "    Created user: $RegularUser" -ForegroundColor Green

    } catch {
        Write-Host "    WARNING: Could not create regular user: $_" -ForegroundColor Yellow
    }
}

# =============================================================================
# Main Setup Function
# =============================================================================

function Initialize-ArrStack {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    Write-Host "`n[Arr Stack] Configuring service connections..." -ForegroundColor Cyan

    $apiKeys = $Config.ApiKeys
    $mediaPath = $Config.MediaPath

    # Service URLs
    $prowlarrUrl = "http://localhost:9696"
    $radarrUrl = "http://localhost:7878"
    $sonarrUrl = "http://localhost:8989"
    $lidarrUrl = "http://localhost:8686"
    $readarrUrl = "http://localhost:8787"
    $jellyfinUrl = "http://localhost:8096"

    # Wait for services
    Write-Host "  Checking service health..." -ForegroundColor Yellow
    $servicesReady = $true

    if (-not (Wait-ForService -Url "$prowlarrUrl/ping" -Name "Prowlarr")) { $servicesReady = $false }
    if (-not (Wait-ForService -Url "$radarrUrl/ping" -Name "Radarr")) { $servicesReady = $false }
    if (-not (Wait-ForService -Url "$sonarrUrl/ping" -Name "Sonarr")) { $servicesReady = $false }
    if (-not (Wait-ForService -Url "$lidarrUrl/ping" -Name "Lidarr")) { $servicesReady = $false }
    if (-not (Wait-ForService -Url "$readarrUrl/ping" -Name "Readarr")) { $servicesReady = $false }

    if (-not $servicesReady) {
        Write-Host "  WARNING: Some services are not ready. Skipping connection setup." -ForegroundColor Yellow
        return
    }

    # Configure Prowlarr → Apps
    Write-Host "  Configuring Prowlarr applications..." -ForegroundColor Yellow
    Add-ProwlarrApplication -ProwlarrUrl $prowlarrUrl -ProwlarrApiKey $apiKeys.Prowlarr `
        -AppName "Radarr" -AppUrl $radarrUrl -AppApiKey $apiKeys.Radarr -AppType "Radarr"
    Add-ProwlarrApplication -ProwlarrUrl $prowlarrUrl -ProwlarrApiKey $apiKeys.Prowlarr `
        -AppName "Sonarr" -AppUrl $sonarrUrl -AppApiKey $apiKeys.Sonarr -AppType "Sonarr"
    Add-ProwlarrApplication -ProwlarrUrl $prowlarrUrl -ProwlarrApiKey $apiKeys.Prowlarr `
        -AppName "Lidarr" -AppUrl $lidarrUrl -AppApiKey $apiKeys.Lidarr -AppType "Lidarr"
    Add-ProwlarrApplication -ProwlarrUrl $prowlarrUrl -ProwlarrApiKey $apiKeys.Prowlarr `
        -AppName "Readarr" -AppUrl $readarrUrl -AppApiKey $apiKeys.Readarr -AppType "Readarr"

    # Configure download clients
    Write-Host "  Configuring download clients..." -ForegroundColor Yellow
    $qbitPassword = $env:ADMIN_PASSWORD
    Add-DownloadClient -ServiceUrl $radarrUrl -ApiKey $apiKeys.Radarr -ServiceType "Radarr" -QBitPassword $qbitPassword
    Add-DownloadClient -ServiceUrl $sonarrUrl -ApiKey $apiKeys.Sonarr -ServiceType "Sonarr" -QBitPassword $qbitPassword
    Add-DownloadClient -ServiceUrl $lidarrUrl -ApiKey $apiKeys.Lidarr -ServiceType "Lidarr" -QBitPassword $qbitPassword
    Add-DownloadClient -ServiceUrl $readarrUrl -ApiKey $apiKeys.Readarr -ServiceType "Readarr" -QBitPassword $qbitPassword

    # Configure root folders (using container paths)
    Write-Host "  Configuring root folders..." -ForegroundColor Yellow
    Add-RootFolder -ServiceUrl $radarrUrl -ApiKey $apiKeys.Radarr -ServiceType "Radarr" -Path "/movies"
    Add-RootFolder -ServiceUrl $sonarrUrl -ApiKey $apiKeys.Sonarr -ServiceType "Sonarr" -Path "/tv"
    Add-RootFolder -ServiceUrl $lidarrUrl -ApiKey $apiKeys.Lidarr -ServiceType "Lidarr" -Path "/music"
    Add-RootFolder -ServiceUrl $readarrUrl -ApiKey $apiKeys.Readarr -ServiceType "Readarr" -Path "/books"

    # Configure Jellyfin
    if (Wait-ForService -Url "$jellyfinUrl/System/Ping" -Name "Jellyfin") {
        Initialize-JellyfinUsers -JellyfinUrl $jellyfinUrl -AdminPassword $env:ADMIN_PASSWORD
    }

    Write-Host "`n  Arr stack configuration complete!" -ForegroundColor Green
}
