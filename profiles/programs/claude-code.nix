# profiles/programs/claude-code.nix
# Declarative Claude Code and MCP server configuration
#
# This module manages:
#   - Claude Code settings (~/.claude/settings.json)
#   - User-scoped MCP servers (~/.claude.json)
#   - Environment variables for MCP authentication
#
{ config, pkgs, lib, ... }:

let
  cfg = config.dotfiles.claude-code;

  # Convert MCP server config to JSON-compatible format
  mcpServerToJson = name: server: {
    type = server.type;
  } // lib.optionalAttrs (server.command != null) {
    command = server.command;
  } // lib.optionalAttrs (server.args != []) {
    args = server.args;
  } // lib.optionalAttrs (server.url != null) {
    url = server.url;
  } // lib.optionalAttrs (server.headers != {}) {
    headers = server.headers;
  } // lib.optionalAttrs (server.env != {}) {
    env = server.env;
  };

  # Build the full MCP config
  mcpConfig = {
    mcpServers = lib.mapAttrs mcpServerToJson cfg.mcpServers;
  };

  # Build settings config
  settingsConfig = {
    env = cfg.env;
  } // lib.optionalAttrs (cfg.permissions.allow != []) {
    "permissions" = {
      "allow" = cfg.permissions.allow;
      "deny" = cfg.permissions.deny;
    };
  };
in
{
  options.dotfiles.claude-code = {
    enable = lib.mkEnableOption "Claude Code configuration";

    # MCP Server definitions
    mcpServers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          type = lib.mkOption {
            type = lib.types.enum [ "stdio" "http" "sse" ];
            default = "stdio";
            description = "Transport type for the MCP server";
          };

          command = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Command to run for stdio servers";
          };

          args = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Arguments for the command";
          };

          url = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "URL for http/sse servers";
          };

          headers = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = {};
            description = "HTTP headers (use \${ENV_VAR} for secrets)";
          };

          env = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = {};
            description = "Environment variables for the server";
          };
        };
      });
      default = {};
      description = "MCP servers to configure at user scope";
      example = lib.literalExpression ''
        {
          github = {
            type = "http";
            url = "https://api.githubcopilot.com/mcp/";
            headers = {
              Authorization = "Bearer \''${GITHUB_TOKEN}";
            };
          };
          filesystem = {
            type = "stdio";
            command = "npx";
            args = [ "-y" "@modelcontextprotocol/server-filesystem" "/home/user/Documents" ];
          };
        }
      '';
    };

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

    # Permission settings
    permissions = {
      allow = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Tools to auto-allow without prompting";
        example = [ "Bash(git:*)" "Read" "Glob" ];
      };

      deny = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Tools to always deny";
      };
    };

  };

  config = lib.mkIf cfg.enable {
    # User-scoped MCP servers (~/.claude.json)
    home.file.".claude.json" = lib.mkIf (cfg.mcpServers != {}) {
      text = builtins.toJSON mcpConfig;
    };

    # Claude settings (~/.claude/settings.json)
    home.file.".claude/settings.json" = lib.mkIf (cfg.env != {} || cfg.permissions.allow != []) {
      text = builtins.toJSON settingsConfig;
    };

    # Ensure claude directory exists
    home.activation.ensureClaudeDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p $HOME/.claude
    '';
  };
}
