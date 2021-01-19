{ self ? {}, nixpkgs ? self.inputs.nixpkgs or <nixpkgs>, ... }:
let
  fromDir = dir: with builtins; let
    lib = import (nixpkgs + "/lib");
    f = name: type: if (type == "regular" || type == "symlink") && !isNull (match "([^.].*)[.]nix" name)
    then import (dir + "/${name}")
    else null;
    in filter (value: ! isNull value) (lib.attrsets.mapAttrsToList f (builtins.readDir dir));
in
{
  nixpkgs.overlays = fromDir ./hotfixes;
}
