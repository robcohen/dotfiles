{
  inputs,
  pkgs,
  config,
  ...
}:

let
  unstable = import inputs.unstable-nixpkgs {
    system = pkgs.system;
  };

in {
  home.packages = [ unstable.ungoogled-chromium ];

  programs.browserpass.enable = true;
  programs.browserpass.browsers = [ "chromium" ];

  home.file.".config/chromium-browser/Default/Preferences".text = builtins.toJSON {
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
  };
}