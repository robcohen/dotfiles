{
  inputs,
  pkgs,
  config,
  ...
}: {

  programs.helix = {
    enable = true;
    programs.helix.settings = {
      theme = "onedark";  
      };
  };
}
