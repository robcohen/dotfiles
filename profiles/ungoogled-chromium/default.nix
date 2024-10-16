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
      enabled_labs_experiments = [
      ];
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
    credentials_enable_service = false;
    spellcheck = {
      dictionaries = [
        "en-US"
      ];
      dictionary = "";
      enabled = true;
    };
    session = {
      restore_on_startup = 0;
    };
    homepage = "about:blank";
    homepage_is_newtabpage = false;
  };
}