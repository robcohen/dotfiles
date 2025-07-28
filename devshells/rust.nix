# Rust development shell
{ pkgs, ... }:

{
  devShells.rust = pkgs.mkShell {
    name = "rust-development";

    packages = with pkgs; [
      cargo
      rustc
      rustfmt
      rust-analyzer
      clippy
      cargo-watch
      cargo-edit
      cargo-audit
      cargo-outdated
      pkg-config
      openssl
      gcc
    ];

    shellHook = ''
      echo "🦀 Rust Development Environment"
      echo "🔧 cargo, rustc, clippy, rust-analyzer available"
      echo "📦 Additional tools: cargo-watch, cargo-edit, cargo-audit"

      # Set environment variables for OpenSSL
      export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"
      export OPENSSL_DIR="${pkgs.openssl.dev}"
      export OPENSSL_LIB_DIR="${pkgs.openssl.out}/lib"
      export OPENSSL_INCLUDE_DIR="${pkgs.openssl.dev}/include"

      # Helpful aliases
      alias cr="cargo run"
      alias cb="cargo build"
      alias ct="cargo test"
      alias cc="cargo check"
      alias cw="cargo watch -x check -x test -x run"
    '';
  };
}
