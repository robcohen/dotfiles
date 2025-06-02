{ config, pkgs, lib, hostFeatures, ... }:

let
  hasFeature = feature: builtins.elem feature hostFeatures;
in {
  # System monitoring services
  systemd.user.services = {
    # Low battery notification
    battery-monitor = lib.mkIf (hasFeature "multimedia" || hasFeature "gaming") {
      Unit = {
        Description = "Battery level monitor";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.bash}/bin/bash -c 'while true; do if [ -d /sys/class/power_supply/BAT0 ]; then level=$(cat /sys/class/power_supply/BAT0/capacity); if [ $level -le 15 ]; then ${pkgs.libnotify}/bin/notify-send \"Low Battery\" \"Battery level: $level%\" --urgency=critical; fi; fi; sleep 300; done'";
        Restart = "always";
        RestartSec = "10";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # Disk space monitor
    disk-space-monitor = {
      Unit = {
        Description = "Disk space monitor";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.bash}/bin/bash -c 'while true; do usage=$(df / | tail -1 | awk \"{print \\$5}\" | sed \"s/%//\"); if [ $usage -ge 90 ]; then ${pkgs.libnotify}/bin/notify-send \"Disk Space Warning\" \"Root filesystem is $usage% full\" --urgency=critical; fi; sleep 3600; done'";
        Restart = "always";
        RestartSec = "60";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };

  # Monitoring-related packages
  home.packages = with pkgs; [
    libnotify  # For notifications
    acpi       # For battery info
  ];
}