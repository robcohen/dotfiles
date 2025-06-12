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
    package = pkgs.gitAndTools.gitFull; # Install git wiith all the optional extras
    userName = "user";  # Will be set via git config after SOPS setup
    userEmail = "user@example.com";  # Will be set via git config after SOPS setup
#    signing.key = "";
#    signing.signByDefault = true;
    extraConfig = {
      core.editor = "\${EDITOR:-vim}";
      # Cache git credentials for 15 minutes
      credential.helper = "cache";
      # Sign all commits using ssh key (only if key exists)
      commit.gpgsign = true;
      gpg.format = "ssh";
      user.signingkey = "~/.ssh/id_ed25519.pub";  # Standard location
      # SSH signature verification
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      push = {
        autoSetupRemote = true;
      };
    };
  };

  # Create SSH allowed signers file for local verification
  home.activation.createAllowedSigners = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [[ -f ~/.ssh/id_ed25519.pub ]]; then
      echo "user@example.com $(cat ~/.ssh/id_ed25519.pub)" > ~/.ssh/allowed_signers
      chmod 644 ~/.ssh/allowed_signers
    fi
  '';
}
