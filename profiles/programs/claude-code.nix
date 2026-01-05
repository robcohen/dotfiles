# profiles/programs/claude-code.nix
# Declarative Claude Code configuration
#
# This module manages:
#   - Claude Code settings (~/.claude/settings.json)
#   - Environment variables, permissions, model, and attribution
#
# NOTE: MCP servers CANNOT be managed here. They are stored in ~/.claude.json
#       which is Claude's state file. Add MCP servers via CLI:
#         claude mcp add <name> -- <command> <args...>
#
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.dotfiles.claude-code;

  # Build permissions object - only include non-empty lists
  permissionsConfig = lib.filterAttrs (n: v: v != [ ]) {
    allow = cfg.permissions.allow;
    deny = cfg.permissions.deny;
    ask = cfg.permissions.ask;
  };

  # Build settings config - only include non-empty/non-null values
  settingsConfig = lib.filterAttrs (n: v: v != { } && v != null) {
    env = cfg.env;
    permissions = permissionsConfig;
    model = cfg.model;
    attribution = cfg.attribution;
  };

  # Check if we have any settings to write
  hasSettings = settingsConfig != { };
in
{
  options.dotfiles.claude-code = {
    enable = lib.mkEnableOption "Claude Code configuration";

    # Environment variables for Claude Code
    env = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Environment variables for Claude Code sessions";
      example = {
        MCP_TIMEOUT = "10000";
        MAX_MCP_OUTPUT_TOKENS = "50000";
      };
    };

    # Permissions configuration
    permissions = {
      allow = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Tool patterns to always allow without prompting";
        example = [
          "Bash(ls:*)"
          "Bash(git:*)"
          "WebFetch(domain:github.com)"
        ];
      };

      deny = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Tool patterns to always deny";
        example = [
          "Read(.env)"
          "Read(secrets/**)"
        ];
      };

      ask = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Tool patterns to always prompt for confirmation";
        example = [
          "Bash(rm:*)"
          "Bash(git push:*)"
        ];
      };
    };

    # Model preference
    model = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Default Claude model to use";
      example = "claude-sonnet-4-20250514";
    };

    # Attribution for commits (disabled by default)
    attribution = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Attribution settings for generated content";
      example = {
        commit = "";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Claude settings (~/.claude/settings.json)
    home.file.".claude/settings.json" = lib.mkIf hasSettings {
      text = builtins.toJSON settingsConfig;
    };

    # Ensure claude directory exists
    home.activation.ensureClaudeDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p $HOME/.claude
    '';
  };
}
