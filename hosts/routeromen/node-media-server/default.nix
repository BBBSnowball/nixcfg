{ pkgs ? import <nixpkgs> {} }:
with pkgs;
mkYarnPackage {
  name = "my-node-media-server";
  src = ./.;
  packageJSON = ./package.json;
  yarnLock = ./yarn.lock;
  # NOTE: this is optional and generated dynamically if omitted
  yarnNix = ./yarn.nix;
}
