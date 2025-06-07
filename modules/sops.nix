# SOPS secrets management module
{ config, lib, pkgs, ... }:

with lib;

{
  # SOPS configuration
  sops = {
    defaultSopsFile = ../secrets.yaml;
    defaultSopsFormat = "yaml";
    
    # Age key file location
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = true;
    };

    # Define secrets that should be available to the system
    secrets = {
      # User configuration secrets
      "user/name" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "user/email" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "user/realName" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "user/githubUsername" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };

      # SSH emergency keys
      "ssh/emergencyKeys" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };

      # Domain configuration
      "domains/primary" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "domains/vpn" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "domains/internal" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };
  };

  # Helper functions to read secrets
  environment.systemPackages = with pkgs; [
    sops
    age
  ];

  # Ensure SOPS service is running
  systemd.services.sops-nix = {
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}