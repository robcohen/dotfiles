{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:
{
  programs.git = {
    # Install git
    enable = true;

    # Additional options for the git program
    package = pkgs.gitFull; # Install git with all the optional extras
#    signing.key = "";
#    signing.signByDefault = true;
    settings = {
      user = {
        name = "robcohen";
        email = "robcohen@users.noreply.github.com";
        signingkey = "~/.ssh/id_ed25519.pub";  # Standard location
      };
      core.editor = "\${EDITOR:-vim}";
      # No credential helper needed - using SSH keys for authentication
      # Sign all commits using ssh key (only if key exists)
      commit.gpgsign = true;
      gpg.format = "ssh";
      # SSH signature verification
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      # Default branch name for new repositories
      init.defaultBranch = "main";
      push = {
        autoSetupRemote = true;
      };
    };
  };

  # Create SSH allowed signers file for local verification
  home.activation.createAllowedSigners = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [[ -f ~/.ssh/id_ed25519.pub ]]; then
      echo "robcohen@users.noreply.github.com $(cat ~/.ssh/id_ed25519.pub)" > ~/.ssh/allowed_signers
      chmod 644 ~/.ssh/allowed_signers
    fi
  '';
}
