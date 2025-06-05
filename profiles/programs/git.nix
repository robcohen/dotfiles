{
  inputs,
  pkgs,
  config,
  lib,
  ...
}: {

programs.git = {
      # Install git
      enable = true;

    # Additional options for the git program
    package = pkgs.gitAndTools.gitFull; # Install git wiith all the optional extras
    userName = "robcohen";
    userEmail = "3231868+robcohen@users.noreply.github.com";
#    signing.key = "";
#    signing.signByDefault = true;
    extraConfig = {
      core.editor = "\${EDITOR:-vim}";
      # Cache git credentials for 15 minutes
      credential.helper = "cache";
      # Sign all commits using ssh key (only if key exists)
      commit.gpgsign = true;
      gpg.format = "ssh";
      user.signingkey = "~/.ssh/id_rsa.pub";
      # SSH signature verification
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      # Use ssh-keygen directly instead of SSH agent for signing
      gpg.ssh.program = "ssh-keygen";
        autoSetupRemote = true;
      };
    };
  };

  # Create SSH allowed signers file for local verification
  home.activation.createAllowedSigners = ''
    if [[ -f ~/.ssh/id_rsa.pub ]]; then
      echo "3231868+robcohen@users.noreply.github.com $(cat ~/.ssh/id_rsa.pub)" > ~/.ssh/allowed_signers
      chmod 644 ~/.ssh/allowed_signers
    fi
  '';
}
