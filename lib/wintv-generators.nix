# lib/wintv-generators.nix
# Functions to generate configuration files from wintv config
#
# This produces:
#   - docker-compose.yml
#   - configuration.dsc.yaml (WinGet Configuration)
#   - kanidm-server.toml
#   - deploy.ps1

{ lib, pkgs }:

let
  # Use nixpkgs YAML generator for proper formatting
  yamlFormat = pkgs.formats.yaml { };

in
rec {

  # ===========================================================================
  # Docker Compose Generator
  # ===========================================================================
  generateDockerCompose =
    cfg:
    let
      # Only include containers explicitly enabled (c.enable defaults to false via mkEnableOption)
      enabledContainers = lib.filterAttrs (_: c: c.enable) cfg.containers;

      # Validate that all dependsOn references point to existing containers
      containerNames = lib.attrNames enabledContainers;
      validateDependsOn =
        name: container:
        let
          invalidDeps = lib.filter (dep: !(lib.elem dep containerNames)) (container.dependsOn or [ ]);
        in
        if invalidDeps != [ ] then
          throw "Container '${name}' depends on non-existent containers: ${lib.concatStringsSep ", " invalidDeps}. Available: ${lib.concatStringsSep ", " containerNames}"
        else
          true;
      # Force evaluation of all dependency checks
      _ = lib.mapAttrs validateDependsOn enabledContainers;

      # Convert short volume syntax to long form for Windows compatibility
      # "C:/path:/container:ro" -> { type = "bind"; source = "C:/path"; target = "/container"; read_only = true; }
      parseVolume =
        vol:
        let
          # Split on colon but handle Windows drive letters (C:)
          parts = lib.splitString ":" vol;
          numParts = lib.length parts;
          # Validate minimum parts (source:target = 2 for Unix, 3 for Windows with drive letter)
          # If first part is a single letter (drive), combine with second part
          isWindowsDrive =
            numParts >= 2
            && lib.stringLength (lib.elemAt parts 0) == 1
            && builtins.match "[A-Za-z]" (lib.elemAt parts 0) != null;
          # Calculate indices with bounds checking
          sourceEndIdx = if isWindowsDrive then 1 else 0;
          targetIdx = if isWindowsDrive then 2 else 1;
          optIdx = if isWindowsDrive then 3 else 2;
          # Safely extract values with fallbacks
          source =
            if isWindowsDrive && numParts > 1 then
              "${lib.elemAt parts 0}:${lib.elemAt parts 1}"
            else if numParts > 0 then
              lib.elemAt parts 0
            else
              vol;
          target = if numParts > targetIdx then lib.elemAt parts targetIdx else "/unknown"; # Fallback for malformed volume
          hasOpts = numParts > optIdx;
          opts = if hasOpts then lib.elemAt parts optIdx else "";
        in
        # Return empty attrs for completely invalid volumes (will be filtered or cause clear error)
        if numParts < 2 then
          throw "Invalid volume specification '${vol}': expected format 'source:target[:options]'"
        else
          {
            type = "bind";
            inherit source target;
          }
          // lib.optionalAttrs (opts == "ro") {
            read_only = true;
          };

      mkService =
        name: container:
        {
          image = container.image;
          container_name = name;
          restart = container.restart or "unless-stopped";
        }
        // lib.optionalAttrs (container.ports or [ ] != [ ]) {
          ports = container.ports;
        }
        // lib.optionalAttrs (container.volumes or [ ] != [ ]) {
          volumes = map parseVolume container.volumes;
        }
        // lib.optionalAttrs (container.environment or { } != { }) {
          environment = lib.mapAttrsToList (k: v: "${k}=${toString v}") (container.environment or { });
        }
        // lib.optionalAttrs (container.gpu or false) {
          devices = [ "nvidia.com/gpu=all" ];
        }
        // lib.optionalAttrs (container.dependsOn or [ ] != [ ]) {
          depends_on = container.dependsOn;
        }
        // lib.optionalAttrs (container.tmpfs or [ ] != [ ]) {
          tmpfs = container.tmpfs;
        };

      compose = {
        # Header comment via x- extension (supported by docker-compose)
        "x-generated" = "by Nix from hosts/wintv/config.nix - do not edit manually";
        services = lib.mapAttrs mkService enabledContainers;
      };
    in
    yamlFormat.generate "docker-compose.yml" compose;

  # ===========================================================================
  # WinGet Configuration (DSC) Generator
  # ===========================================================================
  generateWingetConfig =
    cfg:
    let
      # Windows Optional Features
      featureResources = map (feature: {
        resource = "PSDscResources/WindowsOptionalFeature";
        id = "feature-${lib.toLower feature}";
        directives.allowPrerelease = true;
        settings = {
          Name = feature;
          Ensure = "Present";
        };
      }) (cfg.windows.features or [ ]);

      # WinGet Packages
      packageResources = map (pkg: {
        resource = "Microsoft.WinGet.DSC/WinGetPackage";
        id = "pkg-${lib.replaceStrings [ "." ] [ "-" ] (lib.toLower pkg)}";
        directives.allowPrerelease = true;
        settings = {
          id = pkg;
        };
      }) (cfg.windows.packages or [ ]);

      # Firewall Rules
      firewallResources = lib.mapAttrsToList (name: rule: {
        resource = "Networking/Firewall";
        id = "fw-${lib.toLower name}";
        settings = {
          Name = name;
          DisplayName = rule.description or name;
          Action = "Allow";
          Direction = "Inbound";
          LocalPort = toString rule.port;
          Protocol = rule.protocol or "TCP";
          Ensure = "Present";
        };
      }) (cfg.windows.firewall.rules or { });

      config = {
        "$schema" = "https://aka.ms/configuration-dsc-schema/0.2";
        properties = {
          configurationVersion = "0.2.0";
          resources = featureResources ++ packageResources ++ firewallResources;
        };
      };
    in
    yamlFormat.generate "configuration.dsc.yaml" config;

  # ===========================================================================
  # Kanidm Server Config Generator
  # ===========================================================================
  generateKanidmConfig =
    cfg:
    pkgs.writeText "kanidm-server.toml" ''
      # Generated by Nix - do not edit manually
      # Source: hosts/wintv/config.nix

      bindaddress = "[::]:8443"
      origin = "https://${cfg.domain}:8443"
      domain = "${cfg.domain}"
      tls_chain = "/data/certs/${cfg.domain}.crt"
      tls_key = "/data/certs/${cfg.domain}.key"
      db_path = "/data/kanidm.db"
      trust_x_forward_for = true
      role = "WriteReplica"

      # Admin socket path - must be on tmpfs for Podman on Windows
      adminbindpath = "/run/kanidm/kanidmd.sock"
    '';

  # ===========================================================================
  # Prowlarr Config Generator
  # ===========================================================================
  # API key placeholder is replaced at deploy time with derived key
  generateProwlarrConfig =
    cfg:
    pkgs.writeText "config.xml" ''
      <Config>
        <BindAddress>*</BindAddress>
        <Port>9696</Port>
        <SslPort>6969</SslPort>
        <EnableSsl>False</EnableSsl>
        <LaunchBrowser>False</LaunchBrowser>
        <ApiKey>__PROWLARR_API_KEY__</ApiKey>
        <AuthenticationMethod>None</AuthenticationMethod>
        <AuthenticationRequired>DisabledForLocalAddresses</AuthenticationRequired>
        <Branch>master</Branch>
        <LogLevel>info</LogLevel>
        <AnalyticsEnabled>False</AnalyticsEnabled>
        <InstanceName>Prowlarr</InstanceName>
      </Config>
    '';

  # ===========================================================================
  # Radarr Config Generator
  # ===========================================================================
  generateRadarrConfig =
    cfg:
    pkgs.writeText "config.xml" ''
      <Config>
        <BindAddress>*</BindAddress>
        <Port>7878</Port>
        <SslPort>9898</SslPort>
        <EnableSsl>False</EnableSsl>
        <LaunchBrowser>False</LaunchBrowser>
        <ApiKey>__RADARR_API_KEY__</ApiKey>
        <AuthenticationMethod>None</AuthenticationMethod>
        <AuthenticationRequired>DisabledForLocalAddresses</AuthenticationRequired>
        <Branch>master</Branch>
        <LogLevel>info</LogLevel>
        <AnalyticsEnabled>False</AnalyticsEnabled>
        <InstanceName>Radarr</InstanceName>
      </Config>
    '';

  # ===========================================================================
  # Sonarr Config Generator
  # ===========================================================================
  generateSonarrConfig =
    cfg:
    pkgs.writeText "config.xml" ''
      <Config>
        <BindAddress>*</BindAddress>
        <Port>8989</Port>
        <SslPort>9898</SslPort>
        <EnableSsl>False</EnableSsl>
        <LaunchBrowser>False</LaunchBrowser>
        <ApiKey>__SONARR_API_KEY__</ApiKey>
        <AuthenticationMethod>None</AuthenticationMethod>
        <AuthenticationRequired>DisabledForLocalAddresses</AuthenticationRequired>
        <Branch>main</Branch>
        <LogLevel>info</LogLevel>
        <AnalyticsEnabled>False</AnalyticsEnabled>
        <InstanceName>Sonarr</InstanceName>
      </Config>
    '';

  # ===========================================================================
  # Lidarr Config Generator
  # ===========================================================================
  generateLidarrConfig =
    cfg:
    pkgs.writeText "config.xml" ''
      <Config>
        <BindAddress>*</BindAddress>
        <Port>8686</Port>
        <SslPort>6868</SslPort>
        <EnableSsl>False</EnableSsl>
        <LaunchBrowser>False</LaunchBrowser>
        <ApiKey>__LIDARR_API_KEY__</ApiKey>
        <AuthenticationMethod>None</AuthenticationMethod>
        <AuthenticationRequired>DisabledForLocalAddresses</AuthenticationRequired>
        <Branch>master</Branch>
        <LogLevel>info</LogLevel>
        <AnalyticsEnabled>False</AnalyticsEnabled>
        <InstanceName>Lidarr</InstanceName>
      </Config>
    '';

  # ===========================================================================
  # Readarr Config Generator
  # ===========================================================================
  generateReadarrConfig =
    cfg:
    pkgs.writeText "config.xml" ''
      <Config>
        <BindAddress>*</BindAddress>
        <Port>8787</Port>
        <SslPort>6868</SslPort>
        <EnableSsl>False</EnableSsl>
        <LaunchBrowser>False</LaunchBrowser>
        <ApiKey>__READARR_API_KEY__</ApiKey>
        <AuthenticationMethod>None</AuthenticationMethod>
        <AuthenticationRequired>DisabledForLocalAddresses</AuthenticationRequired>
        <Branch>develop</Branch>
        <LogLevel>info</LogLevel>
        <AnalyticsEnabled>False</AnalyticsEnabled>
        <InstanceName>Readarr</InstanceName>
      </Config>
    '';

  # ===========================================================================
  # Bazarr Config Generator (YAML format)
  # ===========================================================================
  generateBazarrConfig =
    cfg:
    let
      config = {
        general = {
          ip = "0.0.0.0";
          port = 6767;
          base_url = "";
          path_mappings = [ ];
          debug = false;
          branch = "master";
          auto_update = false;
          single_language = false;
          use_radarr = true;
          use_sonarr = true;
          serie_default_enabled = true;
          movie_default_enabled = true;
        };
        auth = {
          type = "None";
          apikey = "__BAZARR_API_KEY__";
        };
        radarr = {
          ip = "localhost";
          port = 7878;
          base_url = "";
          apikey = "__RADARR_API_KEY__";
          ssl = false;
        };
        sonarr = {
          ip = "localhost";
          port = 8989;
          base_url = "";
          apikey = "__SONARR_API_KEY__";
          ssl = false;
        };
      };
    in
    yamlFormat.generate "config.yaml" config;

  # ===========================================================================
  # qBittorrent Config Generator (INI format)
  # ===========================================================================
  generateQBittorrentConfig =
    cfg:
    let
      mediaPath = cfg.paths.media or "C:\\Media";
      downloadPath = "${mediaPath}\\Downloads";
    in
    pkgs.writeText "qBittorrent.conf" ''
      [Application]
      FileLogger\Enabled=true
      FileLogger\Path=C:/ProgramData/wintv/qBittorrent/logs

      [BitTorrent]
      Session\DefaultSavePath=${downloadPath}
      Session\TempPath=${downloadPath}/incomplete
      Session\TempPathEnabled=true
      Session\Port=6881
      Session\MaxConnections=500
      Session\MaxConnectionsPerTorrent=100
      Session\MaxUploads=20
      Session\MaxUploadsPerTorrent=4

      [Preferences]
      General\Locale=en
      Downloads\SavePath=${downloadPath}
      Downloads\TempPath=${downloadPath}/incomplete
      Downloads\ScanDirsV2=@Variant(\0\0\0\x1c\0\0\0\0)
      Connection\PortRangeMin=6881
      WebUI\Port=8080
      WebUI\LocalHostAuth=false
      WebUI\AuthSubnetWhitelistEnabled=true
      WebUI\AuthSubnetWhitelist=0.0.0.0/0
      WebUI\Username=admin
      WebUI\Password_PBKDF2=__QBITTORRENT_PASSWORD_HASH__
    '';

  # ===========================================================================
  # Jellyfin System Config Generator
  # ===========================================================================
  generateJellyfinSystemConfig =
    cfg:
    pkgs.writeText "system.xml" ''
      <?xml version="1.0" encoding="utf-8"?>
      <ServerConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <IsStartupWizardCompleted>true</IsStartupWizardCompleted>
        <EnableMetrics>false</EnableMetrics>
        <EnableNormalizedItemByNameIds>true</EnableNormalizedItemByNameIds>
        <IsPortAuthorized>true</IsPortAuthorized>
        <AutoRunWebApp>true</AutoRunWebApp>
        <EnableCaseSensitiveItemIds>true</EnableCaseSensitiveItemIds>
        <PublicPort>8096</PublicPort>
        <PublicHttpsPort>8920</PublicHttpsPort>
        <HttpServerPortNumber>8096</HttpServerPortNumber>
        <HttpsPortNumber>8920</HttpsPortNumber>
        <EnableHttps>false</EnableHttps>
        <EnableRemoteAccess>true</EnableRemoteAccess>
        <LocalNetworkSubnets />
        <LocalNetworkAddresses />
        <RemoteIPFilter />
        <IsRemoteIPFilterBlacklist>false</IsRemoteIPFilterBlacklist>
        <EnableUPnP>false</EnableUPnP>
        <EnableSSDPTracing>false</EnableSSDPTracing>
        <UDPSendCount>2</UDPSendCount>
        <UDPSendDelay>100</UDPSendDelay>
        <IgnoreVirtualInterfaces>true</IgnoreVirtualInterfaces>
        <VirtualInterfaceNames>vEthernet*</VirtualInterfaceNames>
        <TrustAllIP6Interfaces>false</TrustAllIP6Interfaces>
        <PublishedServerUriBySubnet />
        <EnablePublishedServerUriByRequest>false</EnablePublishedServerUriByRequest>
      </ServerConfiguration>
    '';

  # ===========================================================================
  # Jellyfin Network Config Generator
  # ===========================================================================
  generateJellyfinNetworkConfig =
    cfg:
    pkgs.writeText "network.xml" ''
      <?xml version="1.0" encoding="utf-8"?>
      <NetworkConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <RequireHttps>false</RequireHttps>
        <InternalHttpPort>8096</InternalHttpPort>
        <InternalHttpsPort>8920</InternalHttpsPort>
        <PublicHttpPort>8096</PublicHttpPort>
        <PublicHttpsPort>8920</PublicHttpsPort>
        <AutoDiscovery>true</AutoDiscovery>
        <EnableUPnP>false</EnableUPnP>
        <EnableRemoteAccess>true</EnableRemoteAccess>
        <LocalNetworkSubnets />
        <LocalNetworkAddresses />
        <KnownProxies />
        <IgnoreVirtualInterfaces>true</IgnoreVirtualInterfaces>
        <VirtualInterfaceNames>vEthernet*</VirtualInterfaceNames>
        <EnablePublishedServerUriByRequest>false</EnablePublishedServerUriByRequest>
        <PublishedServerUriBySubnet />
        <RemoteIPFilter />
        <IsRemoteIPFilterBlacklist>false</IsRemoteIPFilterBlacklist>
      </NetworkConfiguration>
    '';

  # ===========================================================================
  # Deploy Script Generator
  # ===========================================================================
  generateDeployScript =
    cfg:
    let
      # Appliance mode settings
      autoLoginEnabled = cfg.windows.autoLogin.enable or false;
      autoLoginUser = cfg.windows.autoLogin.username or "User";
      kioskEnabled = cfg.windows.kiosk.enable or false;
      kioskApp = cfg.windows.kiosk.application or "kodi";
      kioskCustomCmd = cfg.windows.kiosk.customCommand or "";
      podmanSystemSvc = cfg.windows.podmanSystemService or false;
      hasApplianceConfig = autoLoginEnabled || kioskEnabled || podmanSystemSvc;

      # PowerShell boolean strings (pre-computed for proper interpolation)
      psTrue = "$true";
      psFalse = "$false";
      autoLoginEnabledPs = if autoLoginEnabled then psTrue else psFalse;
      kioskEnabledPs = if kioskEnabled then psTrue else psFalse;
      podmanSystemSvcPs = if podmanSystemSvc then psTrue else psFalse;

      # Kodi settings
      kodiEnabled = cfg.kodi.enable or false;
      kodiJellyfinEnabled = cfg.kodi.jellyfin.enable or true;
      kodiJellyfinUrl = cfg.kodi.jellyfin.serverUrl or "http://localhost:8096";
      kodiJellyfinSync = cfg.kodi.jellyfin.syncMode or "native";
      kodiVideoRes = cfg.kodi.video.resolution or "4k";
      kodiVideoHdr = cfg.kodi.video.hdr or true;
      kodiVideoRefresh = cfg.kodi.video.refreshRateMatching or "always";
      kodiAudioPassthrough = cfg.kodi.audio.passthrough or true;
      kodiAudioFormats =
        cfg.kodi.audio.formats or [
          "ac3"
          "eac3"
          "truehd"
          "dts"
          "dtshd"
        ];
      kodiSkin = cfg.kodi.ui.skin or "arctic-horizon-2";
      kodiStartWindow = cfg.kodi.ui.startWindow or "home";
      kodiScreensaverTimeout = cfg.kodi.ui.screensaverTimeout or 5;
      kodiBufferSize = cfg.kodi.performance.bufferSize or 104857600;
      kodiReadFactor = cfg.kodi.performance.readFactor or 8.0;

      # Kodi PowerShell booleans
      kodiJellyfinEnabledPs = if kodiJellyfinEnabled then psTrue else psFalse;
      kodiVideoHdrPs = if kodiVideoHdr then psTrue else psFalse;
      kodiAudioPassthroughPs = if kodiAudioPassthrough then psTrue else psFalse;

      # Rclone settings
      rcloneEnabled = cfg.rclone.enable or false;
      putioEnabled = cfg.rclone.putio.enable or false;
      putioMountDrive = cfg.rclone.putio.mountDrive or "P";
      putioUnionDrive = cfg.rclone.putio.unionDrive or "M";
      syncEnabled = cfg.rclone.sync.enable or false;
      syncDestination = cfg.rclone.sync.destination or "C:\\Media\\Cloud";
      syncIntervalMinutes = cfg.rclone.sync.intervalMinutes or 30;
      syncMinAge = cfg.rclone.sync.minAge or "60m";
      syncDeleteAfter = cfg.rclone.sync.deleteAfterSync or true;

      # Rclone PowerShell booleans
      putioEnabledPs = if putioEnabled then psTrue else psFalse;
      syncEnabledPs = if syncEnabled then psTrue else psFalse;
      syncDeleteAfterPs = if syncDeleteAfter then psTrue else psFalse;

      # +2 for service configs and arr-setup
      totalSteps =
        5
        + (if hasApplianceConfig then 1 else 0)
        + (if kodiEnabled then 1 else 0)
        + (if rcloneEnabled then 1 else 0);
    in
    pkgs.writeText "deploy.ps1" ''
      # Generated by Nix - do not edit manually
      # Source: hosts/wintv/config.nix
      #
      # Run this on the Windows host or remotely via WinRM

      #Requires -RunAsAdministrator
      param(
          [switch]$Apply,
          [switch]$ConfigOnly,
          [switch]$ContainersOnly,
          [switch]$DryRun
      )

      $ErrorActionPreference = "Stop"
      $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
      $Domain = "${cfg.domain}"
      $AppData = "${cfg.paths.appData}"
      $MediaPath = "${cfg.paths.media}"

      Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
      Write-Host "║  WinTV Declarative Deploy                                     ║" -ForegroundColor Cyan
      Write-Host "║  Generated from: hosts/wintv/config.nix                       ║" -ForegroundColor Cyan
      Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
      Write-Host ""

      # ===========================================================================
      # Load Environment and Utilities
      # ===========================================================================

      # Source .env file
      $envFile = Join-Path $ScriptDir ".env"
      if (-not (Test-Path $envFile)) {
          $envFile = Join-Path (Split-Path $ScriptDir -Parent) ".env"
      }

      if (Test-Path $envFile) {
          Write-Host "Loading environment from: $envFile" -ForegroundColor Gray
          Get-Content $envFile | ForEach-Object {
              if ($_ -match '^([^#][^=]+)=(.*)$') {
                  $name = $matches[1].Trim()
                  $value = $matches[2].Trim().Trim('"').Trim("'")
                  [Environment]::SetEnvironmentVariable($name, $value, "Process")
              }
          }
      } else {
          Write-Host "WARNING: No .env file found. Copy .env.example to .env and set ADMIN_PASSWORD" -ForegroundColor Yellow
          if (-not $DryRun) {
              throw "ADMIN_PASSWORD required. Set it in .env file."
          }
      }

      # Source common utilities
      $commonScript = Join-Path $ScriptDir "lib\common.ps1"
      if (Test-Path $commonScript) {
          . $commonScript
      } else {
          Write-Host "WARNING: common.ps1 not found" -ForegroundColor Yellow
      }

      # Validate ADMIN_PASSWORD
      if (-not $env:ADMIN_PASSWORD -and -not $DryRun) {
          throw "ADMIN_PASSWORD environment variable is required. Set it in .env file."
      }

      # Generate derived API keys
      Write-Host "Generating API keys..." -ForegroundColor Gray
      $ApiKeys = @{}
      if ($env:ADMIN_PASSWORD) {
          $ApiKeys = Get-AllApiKeys
          Write-Host "  Generated keys for: $($ApiKeys.Keys -join ', ')" -ForegroundColor Gray
      }

      # ===========================================================================
      # Step 1: Apply Windows Configuration (WinGet DSC)
      # ===========================================================================
      if (-not $ContainersOnly) {
          Write-Host "[1/${toString totalSteps}] Applying Windows configuration..." -ForegroundColor Yellow

          $dscPath = Join-Path $ScriptDir "configuration.dsc.yaml"
          if (Test-Path $dscPath) {
              if ($DryRun) {
                  Write-Host "  DRY RUN: Would run 'winget configure $dscPath'" -ForegroundColor Magenta
              } else {
                  Write-Host "  Running: winget configure $dscPath"
                  winget configure $dscPath --accept-configuration-agreements
              }
          } else {
              Write-Host "  WARNING: configuration.dsc.yaml not found" -ForegroundColor Yellow
          }
      }

      # ===========================================================================
      # Step 2: Deploy Configuration Files
      # ===========================================================================
      if (-not $ContainersOnly) {
          Write-Host ""
          Write-Host "[2/${toString totalSteps}] Deploying configuration files..." -ForegroundColor Yellow

          # Ensure directories exist
          $dirs = @(
              "$AppData\Kanidm",
              "$AppData\Kanidm\certs",
              "$AppData\Caddy"
          )
          foreach ($dir in $dirs) {
              if (-not (Test-Path $dir)) {
                  if ($DryRun) {
                      Write-Host "  DRY RUN: Would create $dir" -ForegroundColor Magenta
                  } else {
                      New-Item -ItemType Directory -Path $dir -Force | Out-Null
                      Write-Host "  Created: $dir" -ForegroundColor Green
                  }
              }
          }

          # Copy Kanidm config
          $kanidmSrc = Join-Path $ScriptDir "kanidm-server.toml"
          $kanidmDst = "$AppData\Kanidm\server.toml"
          if (Test-Path $kanidmSrc) {
              if ($DryRun) {
                  Write-Host "  DRY RUN: Would copy kanidm-server.toml" -ForegroundColor Magenta
              } else {
                  Copy-Item $kanidmSrc $kanidmDst -Force
                  Write-Host "  Deployed: kanidm-server.toml" -ForegroundColor Green
              }
          }

          # Generate TLS certs if needed
          $certPath = "$AppData\Kanidm\certs\$Domain.crt"
          if (-not (Test-Path $certPath)) {
              Write-Host "  Generating TLS certificates..."
              if ($DryRun) {
                  Write-Host "  DRY RUN: Would run tailscale cert" -ForegroundColor Magenta
              } else {
                  & tailscale cert --cert-file "$AppData\Kanidm\certs\$Domain.crt" --key-file "$AppData\Kanidm\certs\$Domain.key" $Domain
                  Write-Host "  Generated TLS certs for $Domain" -ForegroundColor Green
              }
          }
      }

      # ===========================================================================
      # Step 3: Deploy Service Configurations
      # ===========================================================================
      if (-not $ContainersOnly) {
          Write-Host ""
          Write-Host "[3/${toString totalSteps}] Deploying service configurations..." -ForegroundColor Yellow

          # Service config directories
          $serviceConfigs = @(
              @{ Name = "Prowlarr"; Dir = "$AppData\Prowlarr"; Files = @("config.xml") }
              @{ Name = "Radarr"; Dir = "$AppData\Radarr"; Files = @("config.xml") }
              @{ Name = "Sonarr"; Dir = "$AppData\Sonarr"; Files = @("config.xml") }
              @{ Name = "Lidarr"; Dir = "$AppData\Lidarr"; Files = @("config.xml") }
              @{ Name = "Readarr"; Dir = "$AppData\Readarr"; Files = @("config.xml") }
              @{ Name = "Bazarr"; Dir = "$AppData\Bazarr"; Files = @("config.yaml") }
              @{ Name = "qBittorrent"; Dir = "$AppData\qBittorrent"; Files = @("qBittorrent.conf") }
              @{ Name = "Jellyfin"; Dir = "$AppData\Jellyfin\config"; Files = @("system.xml", "network.xml") }
          )

          foreach ($svc in $serviceConfigs) {
              # Create directory if needed
              if (-not (Test-Path $svc.Dir)) {
                  if (-not $DryRun) {
                      New-Item -ItemType Directory -Path $svc.Dir -Force | Out-Null
                  }
              }

              # Deploy each config file
              foreach ($file in $svc.Files) {
                  $srcPath = Join-Path $ScriptDir "configs\$($svc.Name)\$file"
                  $dstPath = Join-Path $svc.Dir $file

                  if (Test-Path $srcPath) {
                      if ($DryRun) {
                          Write-Host "  DRY RUN: Would deploy $($svc.Name)/$file" -ForegroundColor Magenta
                      } else {
                          # Read config, replace API key placeholders
                          $content = Get-Content $srcPath -Raw

                          # Replace API key placeholders
                          $content = $content -replace '__PROWLARR_API_KEY__', $ApiKeys.Prowlarr
                          $content = $content -replace '__RADARR_API_KEY__', $ApiKeys.Radarr
                          $content = $content -replace '__SONARR_API_KEY__', $ApiKeys.Sonarr
                          $content = $content -replace '__LIDARR_API_KEY__', $ApiKeys.Lidarr
                          $content = $content -replace '__READARR_API_KEY__', $ApiKeys.Readarr
                          $content = $content -replace '__BAZARR_API_KEY__', $ApiKeys.Bazarr
                          $content = $content -replace '__JELLYFIN_API_KEY__', $ApiKeys.Jellyfin

                          # Generate qBittorrent password hash (PBKDF2)
                          if ($file -eq "qBittorrent.conf") {
                              # qBittorrent uses PBKDF2-SHA512 with 100000 iterations
                              # Format: @ByteArray(salt:hash)
                              # For simplicity, we'll leave auth disabled initially
                              $content = $content -replace '__QBITTORRENT_PASSWORD_HASH__', '@Invalid()'
                          }

                          # Write processed config
                          Set-Content -Path $dstPath -Value $content -NoNewline
                          Write-Host "  Deployed: $($svc.Name)/$file" -ForegroundColor Green
                      }
                  }
              }
          }
      }

      # ===========================================================================
      # Step 4: Deploy Containers
      # ===========================================================================
      if (-not $ConfigOnly) {
          Write-Host ""
          Write-Host "[4/${toString totalSteps}] Deploying containers..." -ForegroundColor Yellow

          $composePath = Join-Path $ScriptDir "docker-compose.yml"
          if (Test-Path $composePath) {
              # Copy compose file to AppData
              if (-not $DryRun) {
                  Copy-Item $composePath "$AppData\docker-compose.yml" -Force
              }

              # Start containers
              if ($DryRun) {
                  Write-Host "  DRY RUN: Would run podman-compose up -d" -ForegroundColor Magenta
              } else {
                  Push-Location $AppData
                  podman-compose up -d
                  Pop-Location
              }
          }
      }

      # ===========================================================================
      # Step 5: Configure Service Connections
      # ===========================================================================
      if (-not $ConfigOnly) {
          Write-Host ""
          Write-Host "[5/${toString totalSteps}] Configuring service connections..." -ForegroundColor Yellow

          $arrSetupScript = Join-Path $ScriptDir "lib\arr-setup.ps1"
          if (Test-Path $arrSetupScript) {
              . $arrSetupScript

              $arrConfig = @{
                  ApiKeys = $ApiKeys
                  MediaPath = $MediaPath
              }

              if ($DryRun) {
                  Write-Host "  DRY RUN: Would configure Prowlarr -> arr apps" -ForegroundColor Magenta
                  Write-Host "  DRY RUN: Would configure download clients" -ForegroundColor Magenta
                  Write-Host "  DRY RUN: Would configure root folders" -ForegroundColor Magenta
                  Write-Host "  DRY RUN: Would create Jellyfin users" -ForegroundColor Magenta
              } else {
                  Initialize-ArrStack -Config $arrConfig
              }
          } else {
              Write-Host "  WARNING: arr-setup.ps1 not found" -ForegroundColor Yellow
          }
      }

      ${lib.optionalString hasApplianceConfig ''
        # ===========================================================================
        # Step ${toString (5 + 1)}: Configure Appliance Mode
        # ===========================================================================
        Write-Host ""
        Write-Host "[${toString (5 + 1)}/${toString totalSteps}] Configuring appliance mode..." -ForegroundColor Yellow

        # Source the appliance configuration script
        $applianceScript = Join-Path $ScriptDir "lib\appliance.ps1"
        if (Test-Path $applianceScript) {
            . $applianceScript

            $applianceConfig = @{
                AutoLogin = @{
                    Enable = ${autoLoginEnabledPs}
                    Username = "${autoLoginUser}"
                }
                Kiosk = @{
                    Enable = ${kioskEnabledPs}
                    Application = "${kioskApp}"
                    CustomCommand = "${kioskCustomCmd}"
                }
                PodmanSystemService = ${podmanSystemSvcPs}
            }

            if (-not $DryRun) {
                Initialize-ApplianceMode -Config $applianceConfig
            } else {
                Write-Host "  DRY RUN: Would configure appliance mode" -ForegroundColor Magenta
                Write-Host "    Auto-login: ${
                  if autoLoginEnabled then "enabled for ${autoLoginUser}" else "disabled"
                }" -ForegroundColor Magenta
                Write-Host "    Kiosk app: ${
                  if kioskEnabled then kioskApp else "disabled"
                }" -ForegroundColor Magenta
                Write-Host "    Podman service: ${
                  if podmanSystemSvc then "enabled" else "disabled"
                }" -ForegroundColor Magenta
            }
        } else {
            Write-Host "  WARNING: appliance.ps1 not found in lib/" -ForegroundColor Yellow
        }
      ''}

      ${lib.optionalString kodiEnabled ''
        # ===========================================================================
        # Step ${toString (5 + (if hasApplianceConfig then 1 else 0) + 1)}: Configure Kodi Media Center
        # ===========================================================================
        Write-Host ""
        Write-Host "[${
          toString (5 + (if hasApplianceConfig then 1 else 0) + 1)
        }/${toString totalSteps}] Configuring Kodi..." -ForegroundColor Yellow

        # Source the Kodi configuration script
        $kodiScript = Join-Path $ScriptDir "lib\kodi.ps1"
        if (Test-Path $kodiScript) {
            . $kodiScript

            $kodiConfig = @{
                Jellyfin = @{
                    Enable = ${kodiJellyfinEnabledPs}
                    ServerUrl = "${kodiJellyfinUrl}"
                    SyncMode = "${kodiJellyfinSync}"
                }
                Video = @{
                    Resolution = "${kodiVideoRes}"
                    Hdr = ${kodiVideoHdrPs}
                    RefreshRateMatching = "${kodiVideoRefresh}"
                }
                Audio = @{
                    Passthrough = ${kodiAudioPassthroughPs}
                    Formats = @(${lib.concatMapStringsSep ", " (f: "\"${f}\"") kodiAudioFormats})
                }
                UI = @{
                    Skin = "${kodiSkin}"
                    StartWindow = "${kodiStartWindow}"
                    Screensaver = "screensaver.xbmc.builtin.dim"
                    ScreensaverTimeout = ${toString kodiScreensaverTimeout}
                }
                Performance = @{
                    BufferSize = ${toString kodiBufferSize}
                    ReadFactor = ${toString kodiReadFactor}
                }
            }

            if (-not $DryRun) {
                Initialize-Kodi -Config $kodiConfig
            } else {
                Write-Host "  DRY RUN: Would configure Kodi" -ForegroundColor Magenta
                Write-Host "    Jellyfin: ${kodiJellyfinUrl}" -ForegroundColor Magenta
                Write-Host "    Skin: ${kodiSkin}" -ForegroundColor Magenta
                Write-Host "    Video: ${kodiVideoRes} HDR=${
                  if kodiVideoHdr then "yes" else "no"
                }" -ForegroundColor Magenta
                Write-Host "    Audio passthrough: ${
                  if kodiAudioPassthrough then "enabled" else "disabled"
                }" -ForegroundColor Magenta
            }
        } else {
            Write-Host "  WARNING: kodi.ps1 not found in lib/" -ForegroundColor Yellow
        }
      ''}

      ${lib.optionalString rcloneEnabled ''
        # ===========================================================================
        # Step ${
          toString (5 + (if hasApplianceConfig then 1 else 0) + (if kodiEnabled then 1 else 0) + 1)
        }: Configure Rclone Cloud Storage
        # ===========================================================================
        Write-Host ""
        Write-Host "[${
          toString (5 + (if hasApplianceConfig then 1 else 0) + (if kodiEnabled then 1 else 0) + 1)
        }/${toString totalSteps}] Configuring rclone cloud storage..." -ForegroundColor Yellow

        # Source the rclone configuration script
        $rcloneScript = Join-Path $ScriptDir "lib\rclone.ps1"
        if (Test-Path $rcloneScript) {
            . $rcloneScript

            $rcloneConfig = @{
                PutIO = @{
                    Enable = ${putioEnabledPs}
                    MountDrive = "${putioMountDrive}"
                    UnionDrive = "${putioUnionDrive}"
                }
                Sync = @{
                    Enable = ${syncEnabledPs}
                    Destination = "${syncDestination}"
                    IntervalMinutes = ${toString syncIntervalMinutes}
                    MinAge = "${syncMinAge}"
                    DeleteAfterSync = ${syncDeleteAfterPs}
                }
            }

            if (-not $DryRun) {
                Initialize-Rclone -Config $rcloneConfig
            } else {
                Write-Host "  DRY RUN: Would configure rclone" -ForegroundColor Magenta
                Write-Host "    Put.io mount: ${putioMountDrive}:\" -ForegroundColor Magenta
                Write-Host "    Union mount: ${putioUnionDrive}:\ (local + remote)" -ForegroundColor Magenta
                Write-Host "    Sync to: ${syncDestination}" -ForegroundColor Magenta
                Write-Host "    Sync interval: ${toString syncIntervalMinutes} min" -ForegroundColor Magenta
                Write-Host "    Delete after sync: ${
                  if syncDeleteAfter then "yes" else "no"
                }" -ForegroundColor Magenta
            }
        } else {
            Write-Host "  WARNING: rclone.ps1 not found in lib/" -ForegroundColor Yellow
        }
      ''}

      # ===========================================================================
      # Summary
      # ===========================================================================
      Write-Host ""
      Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
      Write-Host "║  Deployment Complete                                          ║" -ForegroundColor Green
      Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
      Write-Host ""
      Write-Host "Services available at:" -ForegroundColor Cyan
      Write-Host "  Jellyfin:     http://$Domain:8096"
      Write-Host "  Kodi:         Local application (auto-starts at login)"
      Write-Host "  Radarr:       http://$Domain:7878"
      Write-Host "  Sonarr:       http://$Domain:8989"
      Write-Host "  Prowlarr:     http://$Domain:9696"
      Write-Host "  Ollama:       http://$Domain:11434"
      Write-Host "  Open WebUI:   http://$Domain:3000"
      Write-Host "  Kanidm:       https://$Domain:8443"
      ${lib.optionalString hasApplianceConfig ''
        Write-Host ""
        Write-Host "Appliance mode:" -ForegroundColor Cyan
        Write-Host "  Auto-login:     ${
          if autoLoginEnabled then "Enabled (${autoLoginUser})" else "Disabled"
        }"
        Write-Host "  Kiosk app:      ${if kioskEnabled then kioskApp else "Disabled"}"
        Write-Host "  Podman service: ${
          if podmanSystemSvc then "System service (starts at boot)" else "User process"
        }"
      ''}
      ${lib.optionalString rcloneEnabled ''
        Write-Host ""
        Write-Host "Rclone cloud storage:" -ForegroundColor Cyan
        Write-Host "  Put.io mount:   ${putioMountDrive}:\\"
        Write-Host "  Union mount:    ${putioUnionDrive}:\\ (local + remote merged)"
        Write-Host "  Sync dest:      ${syncDestination}"
        Write-Host "  Sync interval:  Every ${toString syncIntervalMinutes} minutes"
        Write-Host "  Auto-delete:    ${
          if syncDeleteAfter then "Files removed from put.io after sync" else "Files kept on put.io"
        }"
        Write-Host ""
        Write-Host "NOTE: Run 'rclone config' first to set up put.io OAuth!" -ForegroundColor Yellow
      ''}
    '';

  # ===========================================================================
  # Build Complete Package
  # ===========================================================================
  buildWintvConfig =
    cfg:
    let
      # Path to wintv lib scripts in the source tree
      wintvLibPath = ../hosts/wintv/lib;
    in
    pkgs.runCommand "wintv-config" { } ''
      mkdir -p $out/lib
      mkdir -p $out/configs/{Prowlarr,Radarr,Sonarr,Lidarr,Readarr,Bazarr,qBittorrent,Jellyfin}

      # Copy generated files
      cp ${generateDockerCompose cfg} $out/docker-compose.yml
      cp ${generateWingetConfig cfg} $out/configuration.dsc.yaml
      cp ${generateKanidmConfig cfg} $out/kanidm-server.toml
      cp ${generateDeployScript cfg} $out/deploy.ps1

      # Copy service configuration files (with API key placeholders)
      cp ${generateProwlarrConfig cfg} $out/configs/Prowlarr/config.xml
      cp ${generateRadarrConfig cfg} $out/configs/Radarr/config.xml
      cp ${generateSonarrConfig cfg} $out/configs/Sonarr/config.xml
      cp ${generateLidarrConfig cfg} $out/configs/Lidarr/config.xml
      cp ${generateReadarrConfig cfg} $out/configs/Readarr/config.xml
      cp ${generateBazarrConfig cfg} $out/configs/Bazarr/config.yaml
      cp ${generateQBittorrentConfig cfg} $out/configs/qBittorrent/qBittorrent.conf
      cp ${generateJellyfinSystemConfig cfg} $out/configs/Jellyfin/system.xml
      cp ${generateJellyfinNetworkConfig cfg} $out/configs/Jellyfin/network.xml

      # Copy lib scripts
      cp ${wintvLibPath}/appliance.ps1 $out/lib/
      cp ${wintvLibPath}/kodi.ps1 $out/lib/
      cp ${wintvLibPath}/rclone.ps1 $out/lib/
      cp ${wintvLibPath}/common.ps1 $out/lib/
      cp ${wintvLibPath}/arr-setup.ps1 $out/lib/

      # Make deploy script info file
      cat > $out/README.txt << 'EOF'
      WinTV Configuration Package
      ===========================

      Generated from: hosts/wintv/config.nix
      Build command:  nix build .#wintv-config

      Files:
        docker-compose.yml       - Container definitions
        configuration.dsc.yaml   - Windows host configuration (WinGet DSC)
        kanidm-server.toml       - Kanidm identity server config
        deploy.ps1               - Deployment script
        lib/appliance.ps1        - Appliance mode configuration
        lib/kodi.ps1             - Kodi media center configuration
        lib/rclone.ps1           - Rclone cloud storage
        lib/common.ps1           - Common utilities and API key generation
        lib/arr-setup.ps1        - Arr stack connection setup

      configs/                   - Pre-seeded service configurations
        Prowlarr/config.xml      - Prowlarr indexer manager
        Radarr/config.xml        - Radarr movie manager
        Sonarr/config.xml        - Sonarr TV manager
        Lidarr/config.xml        - Lidarr music manager
        Readarr/config.xml       - Readarr book manager
        Bazarr/config.yaml       - Bazarr subtitle manager
        qBittorrent/qBittorrent.conf - qBittorrent download client
        Jellyfin/system.xml      - Jellyfin media server

      Usage:
        1. Copy your .env file with ADMIN_PASSWORD set
        2. Run as Administrator: .\deploy.ps1 -Apply

      Credentials:
        Admin user:     admin (everywhere)
        Admin password: From ADMIN_PASSWORD in .env
        Regular user:   user / user (for daily use)
        API keys:       Auto-derived from ADMIN_PASSWORD

      Options:
        -DryRun         Show what would be done without making changes
        -ConfigOnly     Only apply Windows config, skip containers
        -ContainersOnly Only deploy containers, skip Windows config
      EOF
    '';
}
