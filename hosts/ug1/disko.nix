{ lib, pkgs, config, disko, ... }:
let
  hostName = config.networking.hostName;
in
{
  config.system.build.disko = rec {
    lib = disko.lib;
    config = import ./partitions-disko.nix;
    packages = lib.packages config;

    createScript = lib.formatScript config pkgs;
    mountScript  = lib.mountScript config pkgs;
    diskoScript  = lib.diskoScript config pkgs;
  };
}
