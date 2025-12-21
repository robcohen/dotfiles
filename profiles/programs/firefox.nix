{ inputs, pkgs, ... }:

let
  unstable = import inputs.unstable-nixpkgs {
    system = pkgs.stdenv.hostPlatform.system;
  };

in {
  programs.firefox = {
    enable = true;
    package = unstable.firefox;

    profiles.default = {
      isDefault = true;

      settings = {
        # WebRTC leak prevention
        "media.peerconnection.enabled" = false;
        "media.peerconnection.ice.default_address_only" = true;
        "media.peerconnection.ice.no_host" = true;
        "media.peerconnection.ice.proxy_only_if_behind_proxy" = true;

        # Additional privacy settings
        "privacy.resistFingerprinting" = true;
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;

        # Disable telemetry
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.unified" = false;
        "toolkit.telemetry.archive.enabled" = false;
        "datareporting.healthreport.uploadEnabled" = false;
        "datareporting.policy.dataSubmissionEnabled" = false;

        # DNS over HTTPS (use Mullvad's when on VPN)
        "network.trr.mode" = 2;  # Enable DoH with fallback

        # Disable prefetching
        "network.prefetch-next" = false;
        "network.dns.disablePrefetch" = true;
        "network.predictor.enabled" = false;

        # Disable WebGL (fingerprinting vector)
        "webgl.disabled" = true;
      };
    };
  };

  programs.browserpass.browsers = [ "chromium" "firefox" ];
}
