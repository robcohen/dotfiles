# Centralized constants for the flake
# Used by system-builders.nix and home-builders.nix
{
  # Supported systems for per-system outputs
  supportedSystems = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  # Default values for configurations
  defaults = {
    username = "user";
    hostType = "desktop";
    hostFeatures = [
      "development"
      "multimedia"
    ];
  };

  # Host definitions with system and features
  # Used by homeConfigurations to determine feature sets
  hosts = {
    slax = {
      system = "x86_64-linux";
      hostType = "desktop";
      hostFeatures = [
        "development"
        "multimedia"
        "gaming"
      ];
    };
    brix = {
      system = "x86_64-linux";
      hostType = "desktop";
      hostFeatures = [
        "development"
        "multimedia"
      ];
    };
    snix = {
      system = "x86_64-linux";
      hostType = "desktop";
      hostFeatures = [
        "development"
        "multimedia"
        "gaming"
      ];
    };
    nixtv-player = {
      system = "x86_64-linux";
      hostType = "appliance";
      hostFeatures = [ ];
    };
  };
}
