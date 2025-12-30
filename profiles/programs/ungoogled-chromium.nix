{
  inputs,
  pkgs,
  config,
  ...
}:

let
  unstable = import inputs.unstable-nixpkgs {
    system = pkgs.stdenv.hostPlatform.system;
  };

  chromiumPackage = unstable.ungoogled-chromium;

  # Helper to fetch extensions from Chrome Web Store
  fetchChromeExtension = { id, version, sha256 }: {
    inherit id version;
    crxPath = builtins.fetchurl {
      name = "${id}.crx";
      url = "https://clients2.google.com/service/update2/crx?response=redirect&prodversion=120&acceptformat=crx2,crx3&x=id%3D${id}%26installsource%3Dondemand%26uc";
      inherit sha256;
    };
  };

  # Chromium Web Store - enables installing extensions from Chrome Web Store
  # https://github.com/NeverDecaf/chromium-web-store
  chromium-web-store = {
    id = "ocaahdebbfolfmndjeplogmgcagdmblk";
    version = "1.5.5.2";
    crxPath = builtins.fetchurl {
      url = "https://github.com/NeverDecaf/chromium-web-store/releases/download/v1.5.5.2/Chromium.Web.Store.crx";
      sha256 = "0fm5qz4gkn8z2chwlk0j1ngwgpadw2vyb56h8ifcfij0qziiyn09";  # pragma: allowlist secret
    };
  };

  # Bitwarden - password manager (unpacked from GitHub releases)
  # https://github.com/bitwarden/clients
  bitwarden = {
    version = "2025.12.0";
    src = pkgs.fetchzip {
      url = "https://github.com/bitwarden/clients/releases/download/browser-v2025.12.0/dist-chrome-2025.12.0.zip";
      sha256 = "sha256-DLEGooAOt/u3dc8iuU1p6Q3+RMx6o1of9EAn6ZMSynU=";  # pragma: allowlist secret
      stripRoot = false;
    };
  };

in {
  # Playwright MCP browser executable path
  home.sessionVariables = {
    PLAYWRIGHT_MCP_EXECUTABLE_PATH = "${chromiumPackage}/bin/chromium";
  };

  programs.chromium = {
    enable = true;
    package = chromiumPackage;
    commandLineArgs = [
      # WebRTC leak prevention - most restrictive setting
      "--webrtc-ip-handling-policy=default_public_interface_only"
      "--force-webrtc-ip-handling-policy"
      "--disable-webrtc-hw-encoding"
      "--disable-webrtc-hw-decoding"
      # Hide shortcuts on new tab page
      "--disable-top-sites"
      # Load unpacked extensions from GitHub
      "--load-extension=${bitwarden.src}"
    ];
    extensions = [
      chromium-web-store
      # bitwarden loaded as unpacked extension below
      # Claude in Chrome - install via chromium-web-store (requires Pro/Max/Team subscription)
      # Extension ID: fcoeoabgfenejglbffodgkkbkcdhcgfn
      # https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn
    ];
  };

  programs.browserpass.enable = true;
  programs.browserpass.browsers = [ "chromium" ];

  # Force overwrite browser-modified Preferences
  # Run `diff-browser-prefs` before `home-manager switch` to review changes
  home.file.".config/chromium/Default/Preferences" = {
    force = true;
    text = builtins.toJSON {
    browser = {
      enabled_labs_experiments = [ ];
    };
    bookmark_bar = {
      show_on_all_tabs = true;
    };
    browser_signin = {
      BrowserSignin = 0;
    };
    sync = {
      SyncDisabled = true;
    };

    # Privacy & Security
    credentials_enable_service = false;
    password_manager_enabled = false;
    safebrowsing = {
      enabled = false;
      extended_reporting_enabled = false;
    };
    search_suggest_enabled = false;
    alternate_error_pages_enabled = false;
    network_prediction_options = 2;  # No network actions

    # Disable various tracking
    enable_do_not_track = true;
    enable_referrers = false;

    # WebRTC settings for privacy
    webrtc = {
      multiple_routes_enabled = false;
      nonproxied_udp_enabled = false;
    };

    spellcheck = {
      dictionaries = [ "en-US" ];
      dictionary = "";
      enabled = true;
    };
    session = {
      restore_on_startup = 0;
    };
    homepage = "about:blank";
    homepage_is_newtabpage = false;

    # Privacy settings without blocking third-party cookies
    profile = {
      default_content_setting_values = {
        geolocation = 2;  # Block
        notifications = 2;  # Block
        media_stream_mic = 2;  # Block
        media_stream_camera = 2;  # Block
      };
    };

    # Pinned extensions in toolbar
    extensions = {
      pinned_extensions = [
        "ccekafbpibgjbnpbojfdepdjolfflbmd"  # Bitwarden (unpacked)
        "fcoeoabgfenejglbffodgkkbkcdhcgfn"  # Claude in Chrome
      ];
    };
  };
  };
}
