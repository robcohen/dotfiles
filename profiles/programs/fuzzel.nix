{ config, pkgs, lib, ... }:

{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        terminal = "${pkgs.alacritty}/bin/alacritty";
        layer = "overlay";
        prompt = "❯ ";
        icon-theme = "Papirus-Dark";
        icons-enabled = true;
        fields = "name,generic,comment,categories,filename,keywords";
        fuzzy = true;
        show-actions = false;
        launch-prefix = "";
        lines = 12;
        width = 45;
        horizontal-pad = 24;
        vertical-pad = 16;
        inner-pad = 8;
      };

      colors = {
        # Catppuccin Mocha theme
        background = "1e1e2eee";
        text = "cdd6f4ff";
        prompt = "89b4faff";
        placeholder = "6c7086ff";
        input = "cdd6f4ff";
        match = "f38ba8ff";
        selection = "313244ff";
        selection-text = "cdd6f4ff";
        selection-match = "f38ba8ff";
        border = "89b4faff";
      };

      border = {
        width = 2;
        radius = 16;
      };

      dmenu = {
        exit-immediately-if-empty = false;
      };
    };
  };
}
