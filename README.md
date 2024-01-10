# Installation


### Local

```
$ sudo nixos-rebuild switch --flake .#slax
$ nix-shell '<home-manager>' -A install
$ home-manager switch --flake .#user@slax
```
for now, run:
```
env -u WAYLAND_DISPLAY code .
```

ephemeral firefox:
```distrobox-ephemeral --image alpine:latest --additional-packages "firefox" -- firefox```
