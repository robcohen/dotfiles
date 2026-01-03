# Thunderbolt/USB4 dock support module
# Tested with: CalDigit TS5 Plus
#
# Provides:
# - Bolt service for persistent Thunderbolt device authorization
# - USBGuard rules for common dock chipsets
# - TLP settings to prevent USB autosuspend issues
# - Kernel modules for USB-C DisplayPort alt mode
# - Optional EDID override for problematic displays
# - Debug mode for troubleshooting
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

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Thunderbolt/USB4 debug logging in kernel";
    };

    edidOverride = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      example = { "HDMI-A-1" = ./edid/lg-ultrahd.bin; };
      description = ''
        EDID firmware overrides for displays with detection issues.
        Keys are connector names (e.g., HDMI-A-1, DP-1), values are paths to EDID binary files.
        Generate EDID with: cat /sys/class/drm/card1-HDMI-A-1/edid > edid.bin
      '';
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
      "i2c_dev" # Required for DDC/CI and EDID reads
    ];

    # Kernel parameters for Thunderbolt/USB4
    boot.kernelParams =
      # Debug logging
      (lib.optionals cfg.debug [
        "thunderbolt.dyndbg=+p"
        "typec.dyndbg=+p"
      ])
      # EDID firmware overrides
      ++ (lib.mapAttrsToList
        (connector: edidPath: "drm.edid_firmware=${connector}:edid/${connector}.bin")
        cfg.edidOverride);

    # Install EDID firmware files
    hardware.firmware = lib.mkIf (cfg.edidOverride != { }) [
      (pkgs.runCommand "edid-firmware" { } ''
        mkdir -p $out/lib/firmware/edid
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList
          (connector: edidPath: "cp ${edidPath} $out/lib/firmware/edid/${connector}.bin")
          cfg.edidOverride)}
      '')
    ];

    # USBGuard rules for common dock chipsets
    services.usbguard.rules = lib.mkAfter ''
      # Thunderbolt/USB4 dock support
      # VIA Labs USB hubs (CalDigit, many others)
      allow id 2109:*
      # Texas Instruments USB controllers
      allow id 0451:*
      # Realtek USB ethernet/card readers (r8152, r8153, r8156)
      allow id 0bda:*
      # Genesys Logic USB hubs
      allow id 05e3:*
      # DisplayLink (USB display adapters)
      allow id 17e9:*
      # ASMedia USB controllers
      allow id 174c:*
      # Fresco Logic USB controllers (common in docks)
      allow id 1b73:*
      # JMicron controllers
      allow id 152d:*
    '';

    # Prevent USB autosuspend issues with docks
    services.tlp.settings = lib.mkIf cfg.disableUsbAutosuspend {
      USB_AUTOSUSPEND = 0;
      # Ensure runtime PM doesn't interfere with dock
      RUNTIME_PM_ON_AC = "auto";
      RUNTIME_PM_ON_BAT = "auto";
    };

    # Debugging/management tools
    environment.systemPackages = with pkgs; [
      bolt # boltctl for thunderbolt management
      usbutils # lsusb
      pciutils # lspci for USB4/TB controllers
      read-edid # parse-edid, get-edid for EDID debugging
      i2c-tools # i2cdetect for DDC/CI
    ];

    # udev rules for Thunderbolt hotplug
    services.udev.extraRules = ''
      # Auto-authorize Thunderbolt devices (security level: user)
      # Remove this if you want manual authorization via boltctl
      ACTION=="add", SUBSYSTEM=="thunderbolt", ATTR{authorized}=="0", ATTR{authorized}="1"

      # Trigger display reconfiguration on dock connect
      ACTION=="add", SUBSYSTEM=="drm", KERNEL=="card*", TAG+="systemd"

      # Ensure stable device naming for dock ethernet
      # CalDigit TS5 Plus uses Realtek r8156 (2.5GbE) or Aquantia (10GbE)
      SUBSYSTEM=="net", ACTION=="add", DRIVERS=="r8152", ATTR{dev_id}=="0x0", NAME="eth-dock"
      SUBSYSTEM=="net", ACTION=="add", DRIVERS=="r8169", ATTR{dev_id}=="0x0", KERNEL=="enp*", NAME="eth-dock"
    '';
  };
}
