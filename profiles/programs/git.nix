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
      commit.gpgsign = lib.mkIf (builtins.pathExists (config.home.homeDirectory + "/.ssh/id_ed25519.pub")) true;
      gpg.format = "ssh";
      user.signingkey = "~/.ssh/id_ed25519.pub";
      push = {
        autoSetupRemote = true;
      };
    };
  };
}
