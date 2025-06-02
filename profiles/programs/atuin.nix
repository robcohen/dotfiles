{ inputs, pkgs, config, ... }:
{
  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    flags = [
      "--disable-up-arrow"  # Don't override up arrow
    ];
    settings = {
      # Privacy settings
      auto_sync = false;
      sync_address = "";
      
      # Search settings
      search_mode = "fuzzy";
      filter_mode = "global";
      style = "compact";
      inline_height = 10;
      
      # History settings
      update_check = false;
      common_prefix = ["sudo"];
      common_subcommands = ["build" "test" "run"];
      
      # Key bindings
      keymap_mode = "vim";
    };
  };
}