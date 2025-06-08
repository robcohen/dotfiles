{
  inputs,
  pkgs,
  config,
  lib,
  ...
}: 
let
  vars = import ../../lib/vars.nix;
in {

programs.git = {
      # Install git
      enable = true;

    # Additional options for the git program
    package = pkgs.gitAndTools.gitFull; # Install git wiith all the optional extras
    userName = vars.user.githubUsername;
    userEmail = vars.user.email;
#    signing.key = "";
#    signing.signByDefault = true;
    extraConfig = {
      core.editor = "\${EDITOR:-vim}";
      # Cache git credentials for 15 minutes
      credential.helper = "cache";
      # Sign all commits using ssh key (only if key exists)
      commit.gpgsign = true;
      gpg.format = "ssh";
      user.signingkey = vars.user.signingKey;
      # SSH signature verification
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      push = {
        autoSetupRemote = true;
      };
    };
  };

  # Create SSH allowed signers file for local verification
  home.activation.createAllowedSigners = ''
    if [[ -f ${vars.user.signingKey} ]]; then
      echo "${vars.user.email} $(cat ${vars.user.signingKey})" > ~/.ssh/allowed_signers
      chmod 644 ~/.ssh/allowed_signers
    fi
  '';
}
