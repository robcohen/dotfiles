{ config, pkgs, lib, ... }:

{
  programs.wlogout = {
    enable = true;
    layout = [
      {
        label = "lock";
        action = "hyprlock";
        text = "Lock";
        keybind = "l";
      }
      {
        label = "logout";
        action = "hyprctl dispatch exit";
        text = "Logout";
        keybind = "e";
      }
      {
        label = "suspend";
        action = "systemctl suspend";
        text = "Suspend";
        keybind = "u";
      }
      {
        label = "hibernate";
        action = "systemctl hibernate";
        text = "Hibernate";
        keybind = "h";
      }
      {
        label = "reboot";
        action = "systemctl reboot";
        text = "Reboot";
        keybind = "r";
      }
      {
        label = "shutdown";
        action = "systemctl poweroff";
        text = "Shutdown";
        keybind = "s";
      }
    ];
    style = ''
      * {
        background-image: none;
        font-family: "JetBrains Mono Nerd Font", monospace;
        font-size: 14px;
      }

      window {
        background-color: transparent;
      }

      button {
        color: #cdd6f4;
        background-color: rgba(30, 30, 46, 0.95);
        border: 2px solid rgba(137, 180, 250, 0.3);
        border-radius: 16px;
        background-repeat: no-repeat;
        background-position: center;
        background-size: 48px;
        min-width: 100px;
        min-height: 100px;
        margin: 12px;
        box-shadow: 0 4px 16px rgba(0, 0, 0, 0.3);
      }

      button:hover {
        background-color: rgba(137, 180, 250, 0.2);
        border-color: #89b4fa;
        color: #89b4fa;
        box-shadow: 0 8px 32px rgba(137, 180, 250, 0.4);
      }

      button:focus {
        background-color: rgba(137, 180, 250, 0.3);
        border-color: #89b4fa;
      }

      #lock {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/lock.png"));
      }

      #logout {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/logout.png"));
      }

      #suspend {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/suspend.png"));
      }

      #hibernate {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/hibernate.png"));
      }

      #reboot {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/reboot.png"));
      }

      #shutdown {
        background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/shutdown.png"));
      }
    '';
  };
}
