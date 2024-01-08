# Installation


### Local

```
$ sudo nixos-rebuild switch --flake .#slax
$ nix-shell '<home-manager>' -A install
$ home-manager switch --flake .#user@slax
```
