# =============================================================================
# Rclone Cloud Storage Configuration
# =============================================================================
# Sets up rclone with put.io integration:
#   - Mount put.io as a drive for immediate streaming
#   - Union mount merging local + remote (local takes priority)
#   - Scheduled sync to move files from cloud to local
#   - Auto-delete from cloud after successful local copy

# =============================================================================
# Configuration Helpers
# =============================================================================

function Get-RcloneConfigPath {
    return "$env:APPDATA\rclone\rclone.conf"
}

function Test-RcloneConfigured {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RemoteName
    )

    $configPath = Get-RcloneConfigPath
    if (-not (Test-Path $configPath)) {
        return $false
    }

    $content = Get-Content $configPath -Raw
    return $content -match "\[$RemoteName\]"
}

function Write-RcloneUnionConfig {
    param(
        [Parameter(Mandatory=$true)]
        [string]$LocalPath,

        [Parameter(Mandatory=$true)]
        [string]$RemoteName
    )

    $configPath = Get-RcloneConfigPath
    $configDir = Split-Path $configPath -Parent

    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    # Check if union remote already exists
    if (Test-RcloneConfigured -RemoteName "media-union") {
        Write-Host "  Union remote already configured" -ForegroundColor Yellow
        return
    }

    # Append union configuration
    $unionConfig = @"

[media-union]
type = union
upstreams = ${LocalPath}:ro ${RemoteName}:ro
action_policy = all
search_policy = ff
"@

    Add-Content -Path $configPath -Value $unionConfig
    Write-Host "  Created union remote: media-union" -ForegroundColor Green
}

# =============================================================================
# Mount Services
# =============================================================================

function Install-RcloneMountService {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RemoteName,

        [Parameter(Mandatory=$true)]
        [string]$DriveLetter,

        [Parameter(Mandatory=$true)]
        [string]$ServiceName
    )

    $rclonePath = (Get-Command rclone -ErrorAction SilentlyContinue).Source
    if (-not $rclonePath) {
        $rclonePath = "${env:ProgramFiles}\rclone\rclone.exe"
    }

    if (-not (Test-Path $rclonePath)) {
        Write-Host "  ERROR: rclone not found" -ForegroundColor Red
        return $false
    }

    # Find NSSM
    $nssmPaths = @(
        "${env:ProgramFiles}\nssm\nssm.exe",
        "${env:ProgramFiles(x86)}\nssm\nssm.exe",
        "${env:LOCALAPPDATA}\Microsoft\WinGet\Links\nssm.exe",
        "C:\ProgramData\chocolatey\bin\nssm.exe"
    )
    $nssmPath = $nssmPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $nssmPath) {
        $nssmCmd = Get-Command nssm -ErrorAction SilentlyContinue
        if ($nssmCmd) { $nssmPath = $nssmCmd.Source }
    }

    if (-not $nssmPath) {
        Write-Host "  ERROR: NSSM not found. Install with: winget install nssm.nssm" -ForegroundColor Red
        return $false
    }

    # Remove existing service if present
    if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
        Write-Host "  Removing existing $ServiceName service..." -ForegroundColor Yellow
        & $nssmPath stop $ServiceName 2>$null
        & $nssmPath remove $ServiceName confirm 2>$null
        Start-Sleep -Seconds 2
    }

    # Create log directory
    $logDir = "C:\ProgramData\wintv\logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    # Install service
    $mountArgs = "mount ${RemoteName}: ${DriveLetter}: --vfs-cache-mode full --vfs-cache-max-age 24h --vfs-read-chunk-size 64M --vfs-read-chunk-size-limit 1G --dir-cache-time 72h --poll-interval 15s --log-file `"$logDir\rclone-${ServiceName}.log`" --log-level INFO"

    & $nssmPath install $ServiceName $rclonePath $mountArgs
    & $nssmPath set $ServiceName DisplayName "Rclone Mount - $RemoteName"
    & $nssmPath set $ServiceName Description "Mounts $RemoteName as drive $DriveLetter`:"
    & $nssmPath set $ServiceName Start SERVICE_AUTO_START
    & $nssmPath set $ServiceName AppStdout "$logDir\rclone-${ServiceName}-stdout.log"
    & $nssmPath set $ServiceName AppStderr "$logDir\rclone-${ServiceName}-stderr.log"

    # Start service
    & $nssmPath start $ServiceName

    Write-Host "  Created mount service: $ServiceName ($RemoteName -> $DriveLetter`:)" -ForegroundColor Green
    return $true
}

# =============================================================================
# Sync Scheduled Task
# =============================================================================

function Install-RcloneSyncTask {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RemoteName,

        [Parameter(Mandatory=$true)]
        [string]$LocalPath,

        [Parameter(Mandatory=$true)]
        [int]$IntervalMinutes,

        [Parameter(Mandatory=$true)]
        [string]$MinAge,

        [Parameter(Mandatory=$true)]
        [bool]$DeleteAfterSync
    )

    $rclonePath = (Get-Command rclone -ErrorAction SilentlyContinue).Source
    if (-not $rclonePath) {
        $rclonePath = "${env:ProgramFiles}\rclone\rclone.exe"
    }

    $taskName = "RcloneSync-$RemoteName"

    # Create destination directory
    if (-not (Test-Path $LocalPath)) {
        New-Item -ItemType Directory -Path $LocalPath -Force | Out-Null
        Write-Host "  Created sync destination: $LocalPath" -ForegroundColor Green
    }

    # Create sync script
    $scriptDir = "C:\ProgramData\wintv\scripts"
    if (-not (Test-Path $scriptDir)) {
        New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
    }

    $logDir = "C:\ProgramData\wintv\logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    # Build rclone command
    $rcloneCmd = if ($DeleteAfterSync) { "move" } else { "copy" }
    $syncScript = @"
# Rclone sync script - moves files from $RemoteName to local storage
`$logFile = "$logDir\rclone-sync-$RemoteName.log"
`$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path `$logFile -Value "`n=== Sync started: `$timestamp ==="

& "$rclonePath" $rcloneCmd "${RemoteName}:" "$LocalPath" ``
    --min-age $MinAge ``
    --transfers 4 ``
    --checkers 8 ``
    --progress ``
    --log-file `$logFile ``
    --log-level INFO ``
    --stats 1m

`$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path `$logFile -Value "=== Sync completed: `$timestamp ==="
"@

    $scriptPath = "$scriptDir\sync-$RemoteName.ps1"
    Set-Content -Path $scriptPath -Value $syncScript

    # Remove existing task
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

    # Create scheduled task
    $action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes)
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null

    Write-Host "  Created sync task: $taskName (every $IntervalMinutes min)" -ForegroundColor Green
    if ($DeleteAfterSync) {
        Write-Host "    Mode: MOVE (deletes from $RemoteName after sync)" -ForegroundColor Cyan
    } else {
        Write-Host "    Mode: COPY (keeps files on $RemoteName)" -ForegroundColor Cyan
    }
}

# =============================================================================
# Main Setup Function
# =============================================================================

function Initialize-Rclone {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    Write-Host "`n[Rclone] Configuring cloud storage..." -ForegroundColor Cyan

    $putioConfig = $Config.PutIO
    $syncConfig = $Config.Sync

    # Check if put.io is configured
    if ($putioConfig.Enable) {
        if (-not (Test-RcloneConfigured -RemoteName "putio")) {
            Write-Host "`n  WARNING: put.io remote not configured!" -ForegroundColor Yellow
            Write-Host "  Run this command to set up put.io:" -ForegroundColor Yellow
            Write-Host "    rclone config" -ForegroundColor White
            Write-Host "  Then select:" -ForegroundColor Yellow
            Write-Host "    n) New remote" -ForegroundColor White
            Write-Host "    Name: putio" -ForegroundColor White
            Write-Host "    Storage: putio" -ForegroundColor White
            Write-Host "    (Follow OAuth prompts)" -ForegroundColor White
            Write-Host ""
            return
        }

        # Create union config (merges local + remote)
        if ($syncConfig.Enable) {
            Write-RcloneUnionConfig -LocalPath $syncConfig.Destination -RemoteName "putio"
        }

        # Install put.io mount service
        Write-Host "  Setting up put.io mount..." -ForegroundColor Yellow
        Install-RcloneMountService -RemoteName "putio" -DriveLetter $putioConfig.MountDrive -ServiceName "RclonePutIO"

        # Install union mount service (if sync enabled)
        if ($syncConfig.Enable) {
            Write-Host "  Setting up union mount..." -ForegroundColor Yellow
            Install-RcloneMountService -RemoteName "media-union" -DriveLetter $putioConfig.UnionDrive -ServiceName "RcloneUnion"
        }
    }

    # Set up sync task
    if ($syncConfig.Enable -and $putioConfig.Enable) {
        Write-Host "  Setting up sync task..." -ForegroundColor Yellow
        Install-RcloneSyncTask `
            -RemoteName "putio" `
            -LocalPath $syncConfig.Destination `
            -IntervalMinutes $syncConfig.IntervalMinutes `
            -MinAge $syncConfig.MinAge `
            -DeleteAfterSync $syncConfig.DeleteAfterSync
    }

    Write-Host "`n  Rclone configuration complete!" -ForegroundColor Green
    Write-Host "  Put.io mount: $($putioConfig.MountDrive):\" -ForegroundColor Cyan
    if ($syncConfig.Enable) {
        Write-Host "  Union mount:  $($putioConfig.UnionDrive):\ (local + remote merged)" -ForegroundColor Cyan
        Write-Host "  Sync dest:    $($syncConfig.Destination)" -ForegroundColor Cyan
        Write-Host "`n  Point Jellyfin at $($putioConfig.UnionDrive):\ for seamless access" -ForegroundColor Yellow
    }
}
