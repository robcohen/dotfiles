# profiles/programs/claude-code.nix
# Declarative Claude Code configuration
#
# This module manages:
#   - Claude Code settings (~/.claude/settings.json)
#   - Environment variables for Claude Code sessions
#
# NOTE: MCP servers CANNOT be managed here. They are stored in ~/.claude.json
#       which is Claude's state file. Add MCP servers via CLI:
#         claude mcp add <name> -- <command> <args...>
#
{ config, pkgs, lib, ... }:

let
  cfg = config.dotfiles.claude-code;

  # Build settings config - only include non-empty values
  settingsConfig = lib.filterAttrs (n: v: v != {}) {
    env = cfg.env;
  };
in
{
  options.dotfiles.claude-code = {
    enable = lib.mkEnableOption "Claude Code configuration";

    # Environment variables for Claude Code
    env = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Environment variables for Claude Code sessions";
      example = {
        MCP_TIMEOUT = "10000";
        MAX_MCP_OUTPUT_TOKENS = "50000";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Claude settings (~/.claude/settings.json)
    home.file.".claude/settings.json" = lib.mkIf (cfg.env != {}) {
      text = builtins.toJSON settingsConfig;
    };

    # Ensure claude directory exists
    home.activation.ensureClaudeDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p $HOME/.claude
    '';
  };
}
