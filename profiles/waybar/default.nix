{
  inputs,
  pkgs,
  config,
  ...
}: {

  programs.waybar.settings = { 
    style = ''
      {
        mainBar = {
          layer = "top";
          position = "top";
          height = 30;
          modules-left = [ "sway/workspaces" "sway/mode" "wlr/taskbar" ];
          modules-center = [ "sway/window" "custom/hello-from-waybar" ];

          "sway/workspaces" = {
            disable-scroll = true;
            all-outputs = true;
          };         
        };
      }
    '';
  };
  
}