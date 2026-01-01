# Thunderbolt/USB4 dock support module
# Tested with: CalDigit TS5 Plus
#
# Provides:
# - Bolt service for persistent Thunderbolt device authorization
# - USBGuard rules for common dock chipsets
# - TLP settings to prevent USB autosuspend issues
# - Kernel modules for USB-C DisplayPort alt mode
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hardware.thunderboltDock;
in
{
  options.hardware.thunderboltDock = {
    enable = lib.mkEnableOption "Thunderbolt/USB4 dock support";

    disableUsbAutosuspend = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable USB autosuspend to prevent dock disconnects";
    };
  };

  config = lib.mkIf cfg.enable {
    # Bolt daemon for Thunderbolt device management and authorization
    services.hardware.bolt.enable = true;

    # Ensure thunderbolt modules are available early
    boot.initrd.availableKernelModules = [
      "thunderbolt"
      "usb_storage"
      "xhci_pci"
    ];

    boot.kernelModules = [
      "typec_displayport" # USB-C DisplayPort alt mode
    ];

    # USBGuard rules for common dock chipsets
    services.usbguard.rules = lib.mkAfter ''
      # Thunderbolt/USB4 dock support
      # VIA Labs USB hubs (CalDigit, many others)
      allow id 2109:*
      # Texas Instruments USB controllers
      allow id 0451:*
      # Realtek USB ethernet/card readers (r8152, r8153)
      allow id 0bda:*
      # Genesys Logic USB hubs
      allow id 05e3:*
      # DisplayLink (USB display adapters)
      allow id 17e9:*
      # ASMedia USB controllers
      allow id 174c:*
    '';

    # Prevent USB autosuspend issues with docks
    services.tlp.settings = lib.mkIf cfg.disableUsbAutosuspend {
      USB_AUTOSUSPEND = 0;
    };

    # Debugging/management tools
    environment.systemPackages = with pkgs; [
      bolt # boltctl for thunderbolt management
      usbutils # lsusb
    ];

    # udev rules for Thunderbolt hotplug
    services.udev.extraRules = ''
      # Auto-authorize Thunderbolt devices (security level: user)
      # Remove this if you want manual authorization via boltctl
      ACTION=="add", SUBSYSTEM=="thunderbolt", ATTR{authorized}=="0", ATTR{authorized}="1"

      # Trigger display reconfiguration on dock connect
      ACTION=="add", SUBSYSTEM=="drm", KERNEL=="card*", TAG+="systemd"
    '';
  };
}
