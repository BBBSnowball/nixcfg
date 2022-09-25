#!/usr/bin/env bash
set -xe
mkdir -p tmp
chown test tmp
nixpkgs=$(nix eval --impure --expr 'with builtins; let x = getFlake (toString ../..); in x.inputs.nixpkgs.outPath' --raw)
machinectl shell test@ \
  `which nix-shell` -p "nodejs-14_x.pkgs.node2nix" -I nixpkgs=$nixpkgs --run "cd $PWD/tmp && node2nix -i ../node-packages.json"
cp tmp/{default.nix,node-env.nix,node-packages.nix} .
