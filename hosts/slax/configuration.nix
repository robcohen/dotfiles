{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:

let
  vars = import ../../lib/vars.nix;
in {

  imports = [
    ./hardware-configuration.nix
    ../common/base.nix
    ../common/security.nix
    ../common/tpm.nix
    ../virtualization.nix
  ];


  networking = {
    hostName = "slax";
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
    networkmanager.enable = true;
  };


  hardware.logitech.wireless = {
    enable = true;
    enableGraphical = true;
  };

  services.pipewire.audio.enable = true;

  swapDevices = [{
    device = vars.hosts.slax.swapPath;
    size = vars.hosts.slax.swapSize;
  }];

  users.users.${vars.user.name}.extraGroups = [ "libvirtd" "kvm" ];



  services.fstrim.enable = true;



}
