{ config, pkgs, lib, hostType, ... }:

{
  # SwayNC - Notification Center for Wayland
  services = lib.mkIf (hostType == "desktop") {
    swaync = {
      enable = true;
      settings = {
        positionX = "right";
        positionY = "top";
        layer = "overlay";
        control-center-layer = "top";
        layer-shell = true;
        cssPriority = "application";
        control-center-margin-top = 10;
        control-center-margin-bottom = 10;
        control-center-margin-right = 10;
        control-center-margin-left = 10;
        notification-icon-size = 64;
        notification-body-image-height = 100;
        notification-body-image-width = 200;
        timeout = 10;
        timeout-low = 5;
        timeout-critical = 0;
        fit-to-screen = true;
        control-center-width = 400;
        control-center-height = 600;
        notification-window-width = 400;
        keyboard-shortcuts = true;
        image-visibility = "when-available";
        transition-time = 200;
        hide-on-clear = false;
        hide-on-action = true;
        script-fail-notify = true;
        widgets = [
          "inhibitors"
          "title"
          "dnd"
          "notifications"
          "mpris"
        ];
        widget-config = {
          inhibitors = {
            text = "Inhibitors";
            button-text = "Clear";
            clear-all-button = true;
          };
          title = {
            text = "Notifications";
            clear-all-button = true;
            button-text = "Clear All";
          };
          dnd = {
            text = "Do Not Disturb";
          };
          mpris = {
            image-size = 96;
            image-radius = 12;
          };
        };
      };
      style = ''
        /* Catppuccin Mocha theme for SwayNC */
        @define-color base #1e1e2e;
        @define-color mantle #181825;
        @define-color crust #11111b;
        @define-color text #cdd6f4;
        @define-color subtext0 #a6adc8;
        @define-color subtext1 #bac2de;
        @define-color surface0 #313244;
        @define-color surface1 #45475a;
        @define-color surface2 #585b70;
        @define-color overlay0 #6c7086;
        @define-color overlay1 #7f849c;
        @define-color blue #89b4fa;
        @define-color lavender #b4befe;
        @define-color sapphire #74c7ec;
        @define-color sky #89dceb;
        @define-color teal #94e2d5;
        @define-color green #a6e3a1;
        @define-color yellow #f9e2af;
        @define-color peach #fab387;
        @define-color maroon #eba0ac;
        @define-color red #f38ba8;
        @define-color mauve #cba6f7;
        @define-color pink #f5c2e7;
        @define-color flamingo #f2cdcd;
        @define-color rosewater #f5e0dc;

        * {
          font-family: "Source Code Pro", monospace;
          font-size: 14px;
          font-weight: 500;
        }

        .control-center {
          background: alpha(@base, 0.95);
          border: 2px solid @blue;
          border-radius: 16px;
          padding: 16px;
        }

        .control-center-list {
          background: transparent;
        }

        .notification-row {
          outline: none;
          margin: 8px 0;
        }

        .notification {
          background: @surface0;
          border-radius: 12px;
          border: 1px solid @surface1;
          padding: 0;
          margin: 0;
        }

        .notification-content {
          padding: 12px;
        }

        .notification-default-action {
          border-radius: 12px;
        }

        .notification-default-action:hover {
          background: @surface1;
        }

        .close-button {
          background: @red;
          color: @base;
          border-radius: 50%;
          padding: 4px;
          margin: 8px;
        }

        .close-button:hover {
          background: @maroon;
        }

        .summary {
          color: @text;
          font-weight: bold;
        }

        .body {
          color: @subtext1;
        }

        .time {
          color: @overlay1;
          font-size: 12px;
        }

        .notification-action {
          background: @surface1;
          color: @text;
          border-radius: 8px;
          margin: 4px;
          padding: 8px;
        }

        .notification-action:hover {
          background: @surface2;
        }

        .widget-title {
          color: @text;
          font-size: 18px;
          font-weight: bold;
          margin: 8px 0;
        }

        .widget-title > button {
          background: @blue;
          color: @base;
          border-radius: 8px;
          padding: 4px 12px;
          font-weight: bold;
        }

        .widget-title > button:hover {
          background: @sapphire;
        }

        .widget-dnd {
          background: @surface0;
          border-radius: 12px;
          padding: 8px 16px;
          margin: 8px 0;
        }

        .widget-dnd > switch {
          background: @surface1;
          border-radius: 12px;
        }

        .widget-dnd > switch:checked {
          background: @blue;
        }

        .widget-dnd > switch slider {
          background: @text;
          border-radius: 50%;
        }

        .widget-inhibitors {
          background: @surface0;
          border-radius: 12px;
          padding: 8px 16px;
          margin: 8px 0;
        }

        .widget-mpris {
          background: @surface0;
          border-radius: 12px;
          padding: 12px;
          margin: 8px 0;
        }

        .widget-mpris-player {
          background: @surface1;
          border-radius: 8px;
          padding: 8px;
        }

        .widget-mpris-title {
          color: @text;
          font-weight: bold;
        }

        .widget-mpris-subtitle {
          color: @subtext0;
        }
      '';
    };
  };
}
