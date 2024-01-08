{
  inputs,
  pkgs,
  config,
  ...
}: {

programs.git = {
      # Install git
      enable = true;
      
    # Additional options for the git program
    package = pkgs.gitAndTools.gitFull; # Install git wiith all the optional extras
    userName = "robcohen";
    userEmail = "robcohen@users.noreply.github.com";
    extraConfig = {
      # Use vim as our default git editor
      core.editor = "vim";
      # Cache git credentials for 15 minutes
      credential.helper = "cache";
    };
  };
}