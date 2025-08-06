{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:

{

  imports = [
    ./hardware-configuration.nix
    ../common/base.nix
    ../common/security.nix
    ../common/tpm.nix
    ../common/sddm.nix
    ../common/swap.nix
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
    device = "/swap/swapfile";
    size = 16384;  # 16GB swap
  }];

  users.users.user.extraGroups = [ "libvirtd" "kvm" ];



  services.fstrim.enable = true;



}
