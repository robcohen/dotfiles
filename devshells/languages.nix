# Programming language development shells
# Aggregates all language-specific development environments
{ pkgs, lib, ... }:

let
  rustShells = import ./rust.nix { inherit pkgs; };
  goShells = import ./go.nix { inherit pkgs; };
  pythonShells = import ./python.nix { inherit pkgs; };
in {
  devShells = {
    # Import all language development shells
    inherit (rustShells.devShells) rust;
    inherit (goShells.devShells) go;
    inherit (pythonShells.devShells) python;

    # Combined development shell with all languages
    languages = pkgs.mkShell {
      name = "multi-language-development";

      packages = with pkgs; [
        # Rust
        cargo rustc rustfmt rust-analyzer clippy

        # Go
        go gopls golangci-lint delve

        # Python
        python3 python3Packages.pip python3Packages.poetry
        python3Packages.black python3Packages.flake8 python3Packages.mypy
        pyright

        # Common tools
        git
        pkg-config
        openssl
        gcc
      ];

      shellHook = ''
        echo "🌐 Multi-Language Development Environment"
        echo "🦀 Rust: cargo, rustc, clippy, rust-analyzer"
        echo "🐹 Go: go, gopls, golangci-lint, delve"
        echo "🐍 Python: python3, pip, poetry, black, mypy"
        echo ""
        echo "💡 Use specific language shells for full toolsets:"
        echo "   nix develop .#rust"
        echo "   nix develop .#go"
        echo "   nix develop .#python"

        # Set environment variables
        export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"
        export GOPATH="$HOME/go"
        export GOBIN="$GOPATH/bin"
        export PATH="$GOBIN:$PATH"
        export PYTHONPATH="$PWD:$PYTHONPATH"
      '';
    };
  };
}
