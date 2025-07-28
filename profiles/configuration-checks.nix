{ config, pkgs, lib, hostname, hostConfig, hostFeatures, hostType, ... }:

let
  hasFeature = feature: builtins.elem feature hostFeatures;
  isDesktop = hostType == "desktop";
  isServer = hostType == "server";

  # Configuration consistency checks
  checkWarnings = [
    {
      condition = hasFeature "gaming" && isServer;
      message = "⚠️  Gaming features enabled on server host '${hostname}' - this may not be optimal";
    }
    {
      condition = hasFeature "multimedia" && !isDesktop;
      message = "⚠️  Multimedia features enabled on non-desktop host '${hostname}' - check if intended";
    }
    {
      condition = hasFeature "development" && hasFeature "gaming" && !isDesktop;
      message = "⚠️  Both development and gaming features on non-desktop host '${hostname}' - unusual configuration";
    }
    {
      condition = builtins.length hostFeatures > 4;
      message = "⚠️  Host '${hostname}' has many features (${toString (builtins.length hostFeatures)}) - consider if all are needed";
    }
  ];

  # Generate warnings for display
  activeWarnings = builtins.filter (w: w.condition) checkWarnings;
  warningMessages = map (w: w.message) activeWarnings;

  # Security checks
  securityChecks = [
    {
      condition = hasFeature "development" && !config.programs.gpg.enable;
      message = "🔒 Development features enabled but GPG not configured - consider enabling for commit signing";
    }
    {
      condition = hasFeature "gaming" && config.services.openssh.enable or false;
      message = "🔒 Gaming and SSH both enabled - ensure SSH is properly secured";
    }
  ];

  activeSecurityWarnings = builtins.filter (w: w.condition) securityChecks;
  securityMessages = map (w: w.message) activeSecurityWarnings;

  # Performance recommendations
  performanceChecks = [
    {
      condition = hasFeature "gaming" && isDesktop;
      message = "🚀 Gaming detected - consider enabling zram, gamemode, and performance governor";
    }
    {
      condition = hasFeature "development" && !hasFeature "gaming";
      message = "🚀 Development setup - consider enabling direnv, nix-index for better workflow";
    }
  ];

  activePerformanceRecommendations = builtins.filter (w: w.condition) performanceChecks;
  performanceMessages = map (w: w.message) activePerformanceRecommendations;

  # Combine all messages
  allMessages = warningMessages ++ securityMessages ++ performanceMessages;

in {
  # Display configuration analysis
  home.file.".config/home-manager/config-analysis.md".text = ''
    # Home Manager Configuration Analysis

    **Host:** ${hostname}
    **Type:** ${hostType}
    **Features:** ${lib.concatStringsSep ", " hostFeatures}
    **Generated:** Auto-generated configuration analysis

    ## Configuration Summary
    - State Version: ${hostConfig.homeManagerStateVersion}
    - Features Count: ${toString (builtins.length hostFeatures)}
    - Host Type: ${if isDesktop then "Desktop Environment" else "Server Environment"}

    ## Active Features Analysis
    ${lib.concatMapStrings (feature: "- ✅ **${feature}**: ${
      if feature == "gaming" then "Performance optimizations, MangoHUD, gaming packages"
      else if feature == "development" then "Development tools, git enhancements, build environments"
      else if feature == "multimedia" then "Media players, codecs, audio/video tools"
      else if feature == "headless" then "Server optimizations, minimal packages"
      else if feature == "backup" then "Backup tools and automation"
      else "Custom feature configuration"
    }\n") hostFeatures}

    ${if allMessages != [] then ''
    ## Recommendations & Warnings
    ${lib.concatMapStrings (msg: "- ${msg}\n") allMessages}
    '' else "## Status\n✅ No warnings or recommendations - configuration looks good!"}

    ## Configuration Status
    - Configured programs: ${toString (builtins.length (builtins.attrNames config.programs))}
    - Active services: ${toString (builtins.length (builtins.attrNames config.services))}
    - State version: ${config.home.stateVersion}
  '';

  # Optional: Add warnings to build output (commented out to avoid spam)
  # warnings = allMessages;
}
