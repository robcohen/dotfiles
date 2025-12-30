# Formatter configuration
# Provides nixfmt-rfc-style for `nix fmt`
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      formatter = pkgs.nixfmt-rfc-style;
    };
}
