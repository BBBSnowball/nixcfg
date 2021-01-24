#!/bin/sh
set -ex
nix build .#nixosConfigurations.routeromen.config.system.build.toplevel -o result-test-1
nixos-rebuild build && mv -Tf result result-test-2
nix-build '<nixpkgs/nixos>' -A system "$@" -I nixpkgs="$(realpath "$(nix-instantiate --eval -E "<nixpkgs>")")" -o result-test-3
for host in rockpro64-snowball ; do
  #nixos-rebuild build --flake .#$host -o result-test-$host-1
  # nix-instantiate for flakes, see https://github.com/NixOS/nix/issues/3908
  nix eval --pure-eval .#nixosConfigurations.$host.config.system.build.toplevel.drvPath
  nix-instantiate -E 'with builtins; with (getFlake (toString ./.)).nixosConfigurations; ('"$host"').config.system.build.toplevel' "$@" --add-root result-test-$host-3
  if [ -e hosts/$host/flake.nix ] ; then
    #nixos-rebuild build --flake ./hosts/$host#$host -o result-test-$host-4
    nix eval --pure-eval ./hosts/$host#nixosConfigurations.$host.config.system.build.toplevel.drvPath
    nix-instantiate -E 'with builtins; with (getFlake (toString ./hosts/'"$host"')).nixosConfigurations; ('"$host"').config.system.build.toplevel' "$@" --add-root result-test-$host-6
  fi
done
