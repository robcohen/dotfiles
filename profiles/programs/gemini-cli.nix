# profiles/programs/gemini-cli.nix
# Declarative Gemini CLI configuration
#
# This module manages:
#   - Gemini CLI settings (~/.gemini/settings.json)
#   - MCP server configuration
#
# NOTE: Authentication is handled separately:
#   - OAuth: `gemini auth login` (recommended - no API key needed)
#   - API Key: Set GEMINI_API_KEY environment variable
#   - Vertex AI: Set GOOGLE_API_KEY and GOOGLE_CLOUD_PROJECT
#
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.dotfiles.gemini-cli;

  # Build MCP servers config
  mcpConfig = lib.filterAttrs (n: v: v != { }) cfg.mcpServers;

  # Build settings config - only include non-empty/non-null values
  settingsConfig = lib.filterAttrs (n: v: v != { } && v != null && v != [ ]) (
    { }
    // lib.optionalAttrs (mcpConfig != { }) { mcpServers = mcpConfig; }
    // lib.optionalAttrs (cfg.theme != null) { theme = cfg.theme; }
    // lib.optionalAttrs (cfg.sandbox != null) { sandbox = cfg.sandbox; }
  );

  # Check if we have any settings to write
  hasSettings = settingsConfig != { };
in
{
  options.dotfiles.gemini-cli = {
    enable = lib.mkEnableOption "Gemini CLI configuration";

    # MCP server configuration
    mcpServers = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            command = lib.mkOption {
              type = lib.types.str;
              description = "Command to run the MCP server";
            };
            args = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Arguments for the MCP server command";
            };
            env = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
              description = "Environment variables for the MCP server (use \${VAR} for expansion)";
            };
          };
        }
      );
      default = { };
      description = "MCP server configurations";
      example = {
        filesystem = {
          command = "npx";
          args = [
            "-y"
            "@anthropic/mcp-filesystem"
            "/home/user"
          ];
        };
      };
    };

    # Theme preference
    theme = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "UI theme (light/dark)";
      example = "dark";
    };

    # Sandbox mode
    sandbox = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Enable sandbox mode for safer execution";
    };
  };

  config = lib.mkIf cfg.enable {
    # Gemini CLI settings (~/.gemini/settings.json)
    home.file.".gemini/settings.json" = lib.mkIf hasSettings {
      text = builtins.toJSON settingsConfig;
    };

    # Ensure gemini directory exists
    home.activation.ensureGeminiDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p $HOME/.gemini
    '';
  };
}
