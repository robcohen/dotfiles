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

      # Include local config generated from SOPS secrets (user.name, user.email)
      includes = [
        { path = "~/.config/git/config.local"; }
      ];

      settings = {
        user = {
          # name and email come from ~/.config/git/config.local (generated from SOPS)
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
    # Reads email from SOPS secret at activation time
    home.activation.createAllowedSigners = lib.hm.dag.entryAfter [ "writeBoundary" "sops-nix" ] ''
      SECRETS_BASE="$HOME/.config/sops-nix/secrets"
      if [[ -f "$SECRETS_BASE/user/email" ]] && [[ -f ${cfg.signingKey} ]]; then
        USER_EMAIL="$(cat "$SECRETS_BASE/user/email")"
        echo "$USER_EMAIL $(cat ${cfg.signingKey})" > "$HOME/.ssh/allowed_signers"
        chmod 644 "$HOME/.ssh/allowed_signers"
      fi
    '';
  };
}
