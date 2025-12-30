{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.dotfiles.git;
in
{
  options.dotfiles.git = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "user";
      description = "Git user name for commits";
    };

    email = lib.mkOption {
      type = lib.types.str;
      default = "user@users.noreply.github.com";
      description = "Git email for commits";
    };

    signingKey = lib.mkOption {
      type = lib.types.str;
      default = "~/.ssh/id_ed25519.pub";
      description = "Path to SSH key for commit signing";
    };
  };

  config = {
    programs.git = {
      enable = true;
      package = pkgs.gitFull;

      settings = {
        user = {
          name = cfg.name;
          email = cfg.email;
          signingkey = cfg.signingKey;
        };
        core.editor = "\${EDITOR:-vim}";
        # Sign all commits using SSH key
        commit.gpgsign = true;
        gpg.format = "ssh";
        gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
        init.defaultBranch = "main";
        push.autoSetupRemote = true;
      };
    };

    # Create SSH allowed signers file for local verification
    home.activation.createAllowedSigners = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [[ -f ${cfg.signingKey} ]]; then
        echo "${cfg.email} $(cat ${cfg.signingKey})" > ~/.ssh/allowed_signers
        chmod 644 ~/.ssh/allowed_signers
      fi
    '';
  };
}
