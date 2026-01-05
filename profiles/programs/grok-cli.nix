# profiles/programs/grok-cli.nix
# Declarative Grok CLI configuration
#
# This module manages:
#   - Grok CLI settings (~/.config/grok-cli/config.json)
#   - Model and endpoint configuration
#
# NOTE: API key should be set via environment variable:
#   - XAI_API_KEY (keys start with "xai-")
#   - Get key from: https://console.x.ai/
#
# NOTE: This configures the third-party grok-cli (@vibe-kit/grok-cli)
#       Install via: bun add -g @vibe-kit/grok-cli
#
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.dotfiles.grok-cli;

  # Build settings config - only include non-null values
  # Note: apiKey is intentionally NOT included - use XAI_API_KEY env var
  settingsConfig = lib.filterAttrs (n: v: v != null && v != [ ] && v != { }) {
    baseURL = cfg.baseURL;
    defaultModel = cfg.defaultModel;
    models = cfg.models;
  };

  hasSettings = settingsConfig != { };
in
{
  options.dotfiles.grok-cli = {
    enable = lib.mkEnableOption "Grok CLI configuration";

    # API endpoint (default is xAI's API)
    baseURL = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "API endpoint URL (defaults to https://api.x.ai/v1)";
      example = "https://api.x.ai/v1";
    };

    # Default model
    defaultModel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Default model to use";
      example = "grok-3-latest";
    };

    # Available models list
    models = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of available models";
      example = [
        "grok-3-latest"
        "grok-3-fast"
        "grok-3-mini-fast"
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    # Grok CLI settings (~/.config/grok-cli/config.json)
    home.file.".config/grok-cli/config.json" = lib.mkIf hasSettings {
      text = builtins.toJSON settingsConfig;
    };

    # Ensure grok-cli directory exists
    home.activation.ensureGrokCliDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p $HOME/.config/grok-cli
    '';
  };
}
