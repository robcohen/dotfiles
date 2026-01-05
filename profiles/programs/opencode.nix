# profiles/programs/opencode.nix
# Declarative OpenCode configuration
#
# This module manages:
#   - OpenCode settings (~/.config/opencode/opencode.json)
#   - Provider and model configuration
#
# NOTE: API keys should be set via environment variables, not in config:
#   - ANTHROPIC_API_KEY, OPENAI_API_KEY, etc.
#   - Or use `opencode auth login` for OAuth
#
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.dotfiles.opencode;

  # Build provider config - filter out empty providers
  providerConfig = lib.filterAttrs (n: v: v != { }) cfg.providers;

  # Build settings config - only include non-empty/non-null values
  settingsConfig = lib.filterAttrs (n: v: v != { } && v != null && v != [ ]) (
    {
      "$schema" = "https://opencode.ai/config.json";
    }
    // lib.optionalAttrs (providerConfig != { }) { provider = providerConfig; }
    // lib.optionalAttrs (cfg.theme != null) { theme = cfg.theme; }
    // lib.optionalAttrs (cfg.keybinds != { }) { keybinds = cfg.keybinds; }
  );

  # Check if we have any settings to write
  hasSettings = settingsConfig != { "$schema" = "https://opencode.ai/config.json"; };
in
{
  options.dotfiles.opencode = {
    enable = lib.mkEnableOption "OpenCode configuration";

    # Provider configuration (e.g., Ollama for local models)
    providers = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            npm = lib.mkOption {
              type = lib.types.str;
              default = "@ai-sdk/openai-compatible";
              description = "NPM package for the provider SDK";
            };
            name = lib.mkOption {
              type = lib.types.str;
              description = "Display name for the provider";
            };
            options = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
              description = "Provider options (e.g., baseURL)";
            };
            models = lib.mkOption {
              type = lib.types.attrsOf (
                lib.types.submodule {
                  options = {
                    name = lib.mkOption {
                      type = lib.types.str;
                      description = "Display name for the model";
                    };
                    tools = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                      description = "Whether the model supports tools";
                    };
                    reasoning = lib.mkOption {
                      type = lib.types.bool;
                      default = false;
                      description = "Whether the model supports reasoning";
                    };
                    options = lib.mkOption {
                      type = lib.types.attrsOf lib.types.anything;
                      default = { };
                      description = "Model-specific options (e.g., num_ctx)";
                    };
                  };
                }
              );
              default = { };
              description = "Models available from this provider";
            };
          };
        }
      );
      default = { };
      description = "AI provider configurations";
      example = {
        ollama = {
          npm = "@ai-sdk/openai-compatible";
          name = "Ollama (local)";
          options.baseURL = "http://localhost:11434/v1";
          models.qwen3-8b = {
            name = "Qwen3 8B";
            tools = true;
          };
        };
      };
    };

    # Theme preference
    theme = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "UI theme";
      example = "dark";
    };

    # Custom keybinds
    keybinds = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Custom keybind mappings";
    };
  };

  config = lib.mkIf cfg.enable {
    # OpenCode settings (~/.config/opencode/opencode.json)
    home.file.".config/opencode/opencode.json" = lib.mkIf hasSettings {
      text = builtins.toJSON settingsConfig;
    };

    # Ensure opencode directory exists
    home.activation.ensureOpencodeDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p $HOME/.config/opencode
    '';
  };
}
