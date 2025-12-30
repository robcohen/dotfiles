# Development shells
# Provides default shell and imports language-specific shells from devshells/
{ self, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      # Import infrastructure shells
      infraShells = import "${self}/devshells/infrastructure.nix" {
        inherit pkgs;
        lib = pkgs.lib;
      };

      # Import language shells
      rustShells = import "${self}/devshells/rust.nix" { inherit pkgs; };
      goShells = import "${self}/devshells/go.nix" { inherit pkgs; };
      pythonShells = import "${self}/devshells/python.nix" { inherit pkgs; };
    in
    {
      devShells = {
        # Default dotfiles development shell
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixfmt-rfc-style
            sops
            age
            qemu
          ];

          shellHook = ''
            # Add scripts to PATH
            export PATH="$PWD/assets/scripts:$PATH"

            # Create convenient aliases
            alias check-versions="$PWD/assets/scripts/check-versions.sh"
            alias update-system="$PWD/assets/scripts/update-system.sh"
            alias update-home-manager="$PWD/assets/scripts/update-home-manager.sh"
            alias full-update="$PWD/assets/scripts/full-update.sh"

            echo "NixOS Infrastructure Development Environment"
            echo ""
            echo "Commands:"
            echo "  nix flake check          - Run all tests"
            echo "  nix fmt                  - Format all nix files"
            echo ""
            echo "System update scripts:"
            echo "  check-versions           - Check for upstream releases"
            echo "  update-system            - Update flake and rebuild NixOS"
            echo "  update-home-manager      - Update Home Manager configuration"
            echo "  full-update              - Run complete system update"
            echo ""
            echo "Build ISOs/VMs:"
            echo "  nix build .#slax-live-iso / .#brix-live-iso / .#emergency-iso"
            echo "  nix build .#slax-vm / .#brix-vm"
            echo ""
            echo "Dev shells: .#rust .#go .#python .#infrastructure .#kubernetes .#security"
          '';
        };

        # Infrastructure shells
        inherit (infraShells.devShells) infrastructure kubernetes security;

        # Language shells
        inherit (rustShells.devShells) rust;
        inherit (goShells.devShells) go;
        inherit (pythonShells.devShells) python;
      };
    };
}
