# Development shells index
# Re-exports all devshells for cleaner imports in flake.nix
{ pkgs, lib ? pkgs.lib }:

let
  infraShells = import ./infrastructure.nix { inherit pkgs lib; };
  rustShells = import ./rust.nix { inherit pkgs; };
  goShells = import ./go.nix { inherit pkgs; };
  pythonShells = import ./python.nix { inherit pkgs; };
  languageShells = import ./languages.nix { inherit pkgs; };
in {
  devShells = {
    # Infrastructure shells
    inherit (infraShells.devShells) infrastructure kubernetes security;

    # Language-specific shells
    inherit (rustShells.devShells) rust;
    inherit (goShells.devShells) go;
    inherit (pythonShells.devShells) python;

    # Multi-language shell
    inherit (languageShells.devShells) languages;
  };
}
