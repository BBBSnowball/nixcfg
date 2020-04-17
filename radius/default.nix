{ config, pkgs, ... }:
let
  radius = pkgs.freeradius;
  configDir = derivation {
    name = "radius-config";
    builder = ./mkconfig.sh;
    #system = builtins.currentSystem;
    system = pkgs.system;

    coreutils = pkgs.coreutils;
    patch = pkgs.patch;
    src = "${radius}/etc/raddb";
    configPatch = ./config.patch;
  };
in {
  services.freeradius.enable = true;
  services.freeradius.configDir = configDir;
  # test: radtest -x username password 127.0.0.1:18120 10 testing123
}
