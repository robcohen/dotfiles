# Go development shell
{ pkgs, ... }:

{
  devShells.go = pkgs.mkShell {
    name = "go-development";

    packages = with pkgs; [
      go
      gopls
      golangci-lint
      gotools
      go-tools
      delve
      gore
      gotests
      gomodifytags
      impl
      gofumpt
    ];

    shellHook = ''
      echo "🐹 Go Development Environment"
      echo "🔧 go, gopls, golangci-lint, delve available"
      echo "📦 Additional tools: gore, gotests, gomodifytags, impl"

      # Set Go environment
      export GOPATH="$HOME/go"
      export GOBIN="$GOPATH/bin"
      export PATH="$GOBIN:$PATH"

      # Helpful aliases
      alias gob="go build"
      alias gor="go run"
      alias got="go test"
      alias gom="go mod"
      alias gof="gofmt -w"
      alias gol="golangci-lint run"
    '';
  };
}
