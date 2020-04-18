{ config, pkgs, lib, ... }:
let
  radius = pkgs.freeradius;
  secretsDir = "/etc/nixos/wifi-ap-eap";
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

  # NixOS unstable has debug disabled by default. As we are still on 19.09,
  # we have to overwrite the start command to disable it.
  systemd.services.freeradius.serviceConfig.ExecStart
    = lib.mkForce "${pkgs.freeradius}/bin/radiusd -f -d ${config.services.freeradius.configDir} -l stdout";

  systemd.services.freeradius.serviceConfig.StateDirectory = "freeradius";
}
