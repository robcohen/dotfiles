# NixOS modules index
# Import individual modules selectively or use `all` for everything
#
# Usage:
#   imports = [ modules.sops modules.virtualization ];
#   # or import everything:
#   imports = modules.all;
let
  hardware = import ./hardware;

  # Define modules in one place to avoid duplication
  coreModules = {
    sops = ./sops.nix;
    virtualization = ./virtualization.nix;
  };

  serviceModules = {
    arr-stack = ./arr-stack.nix;
    jellyfin = ./jellyfin.nix;
    htpc = ./htpc.nix;
  };

  networkingModules = {
    tailscale-mullvad = ./tailscale-mullvad.nix;
    travel-router = ./travel-router.nix;
  };

  # All NixOS-compatible modules (auto-generated)
  nixosModules = coreModules // serviceModules // networkingModules;
in
  # Export individual modules
  nixosModules
  // {
    # Hardware modules (separate namespace)
    inherit hardware;

    # Import all NixOS modules as a list (auto-generated from above)
    all = builtins.attrValues nixosModules ++ hardware.all;
  }
