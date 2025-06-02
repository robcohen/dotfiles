{ config, pkgs, lib, hostname, hostConfig, hostFeatures, hostType, ... }:

{
  # Simple debugging information file
  home.file.".config/home-manager/host-info.txt".text = ''
    Host: ${hostname}
    Type: ${hostType}
    Features: ${lib.concatStringsSep ", " hostFeatures}
    State Version: ${hostConfig.homeManagerStateVersion}
    Programs Count: ${toString (builtins.length (builtins.attrNames config.programs))}
    Services Count: ${toString (builtins.length (builtins.attrNames config.services))}
  '';

  # Add useful shell aliases
  home.shellAliases = {
    hm-switch = "home-manager switch --flake ~/Documents/dotfiles/#user@${hostname}";
    hm-news = "home-manager news --flake ~/Documents/dotfiles/#user@${hostname}";
    hm-gens = "home-manager generations";
    hm-build = "home-manager build --flake ~/Documents/dotfiles/#user@${hostname}";
  };
}