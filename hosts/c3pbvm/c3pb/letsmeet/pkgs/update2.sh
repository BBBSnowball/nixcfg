#!/usr/bin/env bash
set -xe
cd "$1"
chmod -R u+rw tmp
#rm -rf tmp/*
#rm -f tmp/{app,server}/*.nix

cd tmp
nix-build ../default.nix -A src -o src-link -I nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos
cp -LrT src-link src
chmod -R u+rw .
patch -p1 <../patch1.patch

cd src/app
node2nix -l package-lock.json -18 package.json
cd ../server
node2nix -l package-lock.json -18 package.json

