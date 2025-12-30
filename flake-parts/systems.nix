# Supported systems for per-system outputs
# Used by flake-parts to generate outputs for each system
{ ... }:
{
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];
}
