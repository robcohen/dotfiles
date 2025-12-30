# Hardware-specific NixOS modules
{
  mt7925 = ./mt7925.nix;

  # Import all hardware modules as a list
  all = [
    ./mt7925.nix
  ];
}
