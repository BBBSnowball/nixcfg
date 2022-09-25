#!/usr/bin/env bash
set -xe
mkdir -p tmp
chown test tmp
#systemd-run --uid test --pty --same-dir --wait --collect --service-type=exec
nixpkgs=$(nix eval --impure --expr 'with builtins; let x = getFlake (toString ../../..); in x.inputs.nixpkgs.outPath' --raw)
#machinectl shell test@ \
#  `which nix-shell` -p "(nodePackages.override { nodejs = (import $PWD/default.nix {}).nodejs; }).node2nix" -I nixpkgs=$nixpkgs --run "$PWD/update2.sh $PWD"
machinectl shell test@ \
  `which nix-shell` -p "nodePackages.node2nix" -I nixpkgs=$nixpkgs --run "$PWD/update2.sh $PWD"

diff tmp/src/app/node-env.nix tmp/src/server/node-env.nix
cp tmp/src/app/node-packages.nix    node-packages-app.nix
cp tmp/src/server/node-packages.nix node-packages-server.nix
