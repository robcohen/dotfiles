{
  inputs,
  pkgs,
  config,
  ...
}: {

  programs.wofi = { 
    enable = true;
    settings = {
      location = "bottom-right";
      allow_markup = true;
      width = 250;
    }; 
  };
} 
