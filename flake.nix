{
  description = "Rob Cohen nix config";

  inputs = {
    # Nixpkgs
    stable-nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    unstable-nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Home manager
    home-manager.url = "github:nix-community/home-manager/release-23.11";
    home-manager.inputs.nixpkgs.follows = "stable-nixpkgs";
    hardware.url = "github:nixos/nixos-hardware";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = {
    self,
    stable-nixpkgs,
    unstable-nixpkgs,
    home-manager,
    sops-nix,
    ...
  } @ inputs: let
    inherit (self) outputs;
  in {
    # Available through 'nixos-rebuild --flake .#your-hostname'
    nixosConfigurations = {
      slax = stable-nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        # > Our main nixos configuration file <
        modules = [
          ./hosts/slax/configuration.nix
          sops-nix.nixosModules.sops
        ];
      };
    };

    # Available through 'home-manager --flake .#your-username@your-hostname'
    homeConfigurations = {
      "user@slax" = home-manager.lib.homeManagerConfiguration {
        pkgs = stable-nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = {inherit inputs outputs;};
        modules = [./profiles/user.nix];
      };
    };
  };
}
