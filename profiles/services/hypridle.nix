{ config, pkgs, lib, ... }:

{
  services.hypridle = {
    enable = true;

    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";  # Avoid starting multiple hyprlock instances
        before_sleep_cmd = "loginctl lock-session";  # Lock before suspend
        after_sleep_cmd = "hyprctl dispatch dpms on";  # Turn on display after suspend
        ignore_dbus_inhibit = false;  # Respect idle inhibitors (e.g., video playback)
      };

      listener = [
        # Dim screen after 2.5 minutes
        {
          timeout = 150;
          on-timeout = "brightnessctl -s set 10%";  # Save current brightness, then dim
          on-resume = "brightnessctl -r";  # Restore previous brightness
        }
        # Lock screen after 5 minutes
        {
          timeout = 300;
          on-timeout = "loginctl lock-session";
        }
        # Turn off screen after 6 minutes
        {
          timeout = 360;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        # Suspend after 15 minutes
        {
          timeout = 900;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };
}
