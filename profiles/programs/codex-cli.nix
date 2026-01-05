# profiles/programs/codex-cli.nix
# Declarative OpenAI Codex CLI configuration
#
# This module manages:
#   - Codex CLI settings (~/.codex/config.toml)
#   - Shell environment policy, features, and model providers
#
# NOTE: API keys should be set via environment variables:
#   - OPENAI_API_KEY for OpenAI
#   - AZURE_OPENAI_API_KEY for Azure
#   - Or use alternative providers via model_providers config
#
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.dotfiles.codex-cli;

  # Helper to convert Nix attrs to TOML format
  toTOML =
    attrs:
    let
      formatValue =
        v:
        if builtins.isBool v then
          (if v then "true" else "false")
        else if builtins.isInt v then
          toString v
        else if builtins.isString v then
          ''"${v}"''
        else if builtins.isList v then
          "[${lib.concatMapStringsSep ", " formatValue v}]"
        else if builtins.isAttrs v then
          "{ ${lib.concatStringsSep ", " (lib.mapAttrsToList (k: val: "${k} = ${formatValue val}") v)} }"
        else
          toString v;

      formatSection =
        prefix: attrs:
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            k: v:
            if
              builtins.isAttrs v && !(lib.any (x: builtins.isAttrs x || builtins.isList x) (lib.attrValues v))
            then
              "${if prefix != "" then "${prefix}." else ""}${k} = ${formatValue v}"
            else if builtins.isAttrs v then
              "[${if prefix != "" then "${prefix}." else ""}${k}]\n${formatSection "" v}"
            else
              "${k} = ${formatValue v}"
          ) attrs
        );
    in
    formatSection "" attrs;

  # Build shell environment policy
  shellEnvPolicy = lib.filterAttrs (n: v: v != null && v != [ ] && v != { }) {
    "inherit" = cfg.shellEnvironmentPolicy.inheritEnv;
    exclude = cfg.shellEnvironmentPolicy.exclude;
    include_only = cfg.shellEnvironmentPolicy.includeOnly;
    set = cfg.shellEnvironmentPolicy.set;
  };

  # Build features config
  featuresConfig = lib.filterAttrs (n: v: v) cfg.features;

  # Build full config
  configAttrs = lib.filterAttrs (n: v: v != { } && v != null) {
    model = cfg.model;
    shell_environment_policy = shellEnvPolicy;
    features = featuresConfig;
    model_providers = cfg.modelProviders;
  };

  hasSettings = configAttrs != { };
in
{
  options.dotfiles.codex-cli = {
    enable = lib.mkEnableOption "Codex CLI configuration";

    # Default model
    model = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Default model to use";
      example = "gpt-4.1";
    };

    # Shell environment policy - controls what env vars are passed to subprocesses
    shellEnvironmentPolicy = {
      inheritEnv = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "none"
            "core"
            "all"
          ]
        );
        default = null;
        description = "Base environment inheritance (none, core, or all). Maps to 'inherit' in config.";
      };

      exclude = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Environment variable patterns to exclude (supports wildcards)";
        example = [
          "AWS_*"
          "AZURE_*"
          "OPENAI_API_KEY"
        ];
      };

      includeOnly = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Only include these environment variables";
        example = [
          "PATH"
          "HOME"
        ];
      };

      set = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Explicitly set environment variables";
        example = {
          MY_FLAG = "1";
        };
      };
    };

    # Feature toggles
    features = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = { };
      description = "Feature flags to enable/disable";
      example = {
        shell_snapshot = true;
        web_search_request = true;
      };
    };

    # Custom model providers (e.g., Azure, Ollama)
    modelProviders = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Display name for the provider";
            };
            base_url = lib.mkOption {
              type = lib.types.str;
              description = "API base URL";
            };
            env_key = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Environment variable name for API key";
            };
            wire_api = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "API wire format (e.g., responses)";
            };
            query_params = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
              description = "Query parameters to add to requests";
            };
          };
        }
      );
      default = { };
      description = "Custom model provider configurations";
      example = {
        ollama = {
          name = "Ollama";
          base_url = "http://localhost:11434/v1";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Codex CLI settings (~/.codex/config.toml)
    home.file.".codex/config.toml" = lib.mkIf hasSettings {
      text = toTOML configAttrs;
    };

    # Ensure codex directory exists
    home.activation.ensureCodexDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p $HOME/.codex
    '';
  };
}
