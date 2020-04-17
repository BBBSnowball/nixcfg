{ config, pkgs, lib, ... }:
let
  radius = pkgs.freeradius;
  secretsDir = "/etc/nixos/radius";
  configDir = derivation {
    name = "radius-config";
    builder = ./mkconfig.sh;
    #system = builtins.currentSystem;
    system = pkgs.system;

    inherit (pkgs) coreutils patch;
    inherit secretsDir;
    src = "${radius}/etc/raddb";
    configPatch = ./config.patch;
  };
in {
  services.freeradius.enable = true;
  services.freeradius.configDir = configDir;
  # test: radtest -x username password 127.0.0.1:18120 10 testing123

  systemd.services.freeradius.serviceConfig.StateDirectory = "freeradius";
}
