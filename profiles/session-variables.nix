{ pkgs, ... }:
{
  home.sessionVariables = {
    ELECTRON_DEFAULT_BROWSER = "brave";
    EDITOR = "vim";
    NIXOS_OZONE_WL = "1";
    LIBVA_DRIVER_NAME = "i965";
    MOZ_DISABLE_RDD_SANDBOX = "1";

    # SSH askpass configuration
    SSH_ASKPASS = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";
    SSH_ASKPASS_REQUIRE = "prefer";
  };
}
