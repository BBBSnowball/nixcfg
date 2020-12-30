{ config, pkgs, lib, ... }:
{
  services.ddclient = {
    enable = true;
    configFile = "/etc/nixos/secret/ddclient.conf";
  };

  systemd.services.ddclient.serviceConfig.User = "ddclient-dynamic";
  systemd.services.ddclient.serviceConfig.ExecStartPre = lib.mkForce "+${lib.getBin pkgs.coreutils}/bin/install -o ddclient-dynamic -m400 ${config.services.ddclient.configFile} /run/ddclient/ddclient.conf";
}
