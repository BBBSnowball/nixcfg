{pkgs ? import <nixpkgs> {}}:

pkgs.callPackage ./default.nix {libliftoff = import ../libliftoff/release.nix { inherit pkgs; }; }
