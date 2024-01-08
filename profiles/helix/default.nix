{
  inputs,
  pkgs,
  config,
  ...
}: {

  programs.helix = {
    enable = true;
    settings = {
      theme = "onedarker";
    };
  };
}
