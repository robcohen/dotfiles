# TRACKING: MT7925 WiFi/Bluetooth Support
# Hardware: ThinkPad P16s Gen 4, MediaTek MT7925 (PCI 14c3:7925)
#
# Known issues:
# - Kernel 6.19 regression: WiFi interface not detected (testing kernel auto-updated)
# - Power management causes disconnections at multiple levels
# - Bluetooth requires lockKernelModules = false for firmware loading
#
# Workarounds applied:
# - Pin kernel to 6.18 until 6.19+ regression fixed
# - Disable power management at 4 levels (NM, modprobe, systemd, TLP)
# - disable_clc=1 for stability (Country Location Code causes issues)
# - Restart NetworkManager on resume from suspend
#
# Test changes: Run ~/wifi/wifi-diag.sh before/after
# Upstream bugs: TBD (run diagnostics on 6.19 to gather info)
#
# References:
# - https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2118755
# - https://lists.infradead.org/pipermail/linux-mediatek/
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hardware.mediatek.mt7925;
in
{
  options.hardware.mediatek.mt7925 = {
    enable = lib.mkEnableOption "MediaTek MT7925 WiFi/Bluetooth support with stability workarounds";
  };

  config = lib.mkIf cfg.enable {
    # ==========================================================================
    # KERNEL
    # ==========================================================================
    # Pin to 6.18 - testing kernel moved to 6.19 which has MT7925 regression
    boot.kernelPackages = pkgs.linuxPackages_6_18;

    # Bluetooth modules - load explicitly at boot for MT7925 combo device
    boot.kernelModules = [
      "btusb"
      "btmtk" # MediaTek Bluetooth
      "btintel" # Fallback
      "btrtl" # Fallback
      "btbcm" # Fallback
    ];

    # Kernel module options for MT7925 stability
    boot.extraModprobeConfig = ''
      # Bluetooth USB options
      options btusb reset=1 enable_autosuspend=0
      options bluetooth disable_ertm=1

      # MT7925e WiFi - disable all power management for stability
      options mt7925e disable_aspm=1
      options mt7925e power_save=0
      options mt76_connac_lib pm_enable=0
      options mt76 disable_usb_sg=1

      # Disable CLC (Country Location Code) - known workaround for 6GHz stability
      options mt7925-common disable_clc=1

      # Force firmware path for reliable loading
      options firmware_class path=/run/current-system/firmware
    '';

    # Kernel parameters for WiFi/Bluetooth power management
    boot.kernelParams = [
      "iwlwifi.power_save=0" # Also disable Intel WiFi PM if present
      "btusb.enable_autosuspend=0"
      "usbcore.autosuspend=-1" # Global USB autosuspend off for Bluetooth
    ];

    # ==========================================================================
    # FIRMWARE
    # ==========================================================================
    # Allow Bluetooth firmware loading (requires relaxed kernel lockdown)
    security.lockKernelModules = false;

    # ==========================================================================
    # NETWORKMANAGER
    # ==========================================================================
    networking.networkmanager = {
      wifi.macAddress = "preserve"; # Keep hardware MAC to prevent disconnections
      wifi.powersave = false; # Disable WiFi power saving
      wifi.scanRandMacAddress = false; # Don't randomize MAC during scans
    };

    # ==========================================================================
    # UDEV RULES
    # ==========================================================================
    services.udev.extraRules = ''
      # MediaTek MT7925 PCIe WiFi/Bluetooth combo - force load Bluetooth modules
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x14c3", ATTR{device}=="0x7925", RUN+="${pkgs.kmod}/bin/modprobe btusb", RUN+="${pkgs.kmod}/bin/modprobe btmtk"

      # Disable WiFi power management immediately when interface appears
      ACTION=="add", SUBSYSTEM=="net", DRIVERS=="mt7925e", RUN+="${pkgs.iw}/bin/iw dev %k set power_save off"

      # MediaTek MT7925 Bluetooth USB variants - disable autosuspend
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", ATTR{idProduct}=="e616", ATTR{authorized}="1", ATTR{power/autosuspend}="-1"
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", ATTR{idProduct}=="e025", ATTR{authorized}="1", ATTR{power/autosuspend}="-1"

      # Force Bluetooth module loading when WiFi interface appears (backup trigger)
      ACTION=="add", SUBSYSTEM=="net", DRIVERS=="mt7925e", RUN+="${pkgs.kmod}/bin/modprobe btusb", RUN+="${pkgs.kmod}/bin/modprobe btmtk"
    '';

    # ==========================================================================
    # SYSTEMD SERVICES
    # ==========================================================================
    # Backup service to ensure power management is disabled after boot
    # Uses dynamic interface detection instead of hardcoded name
    systemd.services.mt7925-power-management-fix = {
      description = "Disable WiFi power management for MT7925e";
      after = [ "network-pre.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "mt7925-pm-fix" ''
          # Disable power save on all wireless interfaces
          for iface in /sys/class/net/wl*; do
            if [ -e "$iface" ]; then
              name=$(basename "$iface")
              ${pkgs.iw}/bin/iw dev "$name" set power_save off 2>/dev/null || true
            fi
          done
          # Disable driver-level power management
          echo 0 > /sys/module/mt76_connac_lib/parameters/pm_enable 2>/dev/null || true
        '';
      };
    };

    # Restart NetworkManager after suspend to fix WiFi reconnection issues
    systemd.services.mt7925-resume-fix = {
      description = "Fix MT7925 WiFi after suspend";
      after = [
        "suspend.target"
        "hibernate.target"
        "hybrid-sleep.target"
      ];
      wantedBy = [
        "suspend.target"
        "hibernate.target"
        "hybrid-sleep.target"
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/systemctl restart NetworkManager.service";
      };
    };

    # ==========================================================================
    # TLP POWER MANAGEMENT
    # ==========================================================================
    # Prevent TLP from interfering with MT7925 power management
    services.tlp.settings = {
      # Disable WiFi power management
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "off";

      # Blacklist MT7925e driver from runtime PM (auto-detection via driver name)
      RUNTIME_PM_DRIVER_BLACKLIST = "mt7925e";

      # Disable USB autosuspend (affects Bluetooth)
      USB_AUTOSUSPEND = 0;
    };

    # ==========================================================================
    # USBGUARD
    # ==========================================================================
    # Allow MT7925 Bluetooth through USBGuard
    services.usbguard.rules = lib.mkAfter ''
      # MediaTek MT7925 Bluetooth
      allow id 0e8d:e025
      allow id 0e8d:e616
      allow id 0e8d:* # All MediaTek USB devices
    '';

    # ==========================================================================
    # BLUETOOTH
    # ==========================================================================
    hardware.bluetooth.settings = {
      General = {
        # Experimental features for better MT7925 support
        Experimental = true;
        KernelExperimental = true;
        # Extended timeouts for firmware loading
        DiscoverableTimeout = 0;
        PairableTimeout = 0;
        AutoConnectTimeout = 60;
      };
      Policy = {
        # Aggressive reconnection for unreliable connections
        ReconnectAttempts = 7;
        ReconnectIntervals = "1,2,4,8,16,32,64";
      };
    };
  };
}
