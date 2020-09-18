{ config, pkgs, ... }:
{
  services.ddclient = {
    enable = true;
    configFile = "/etc/nixos/private/secret/ddclient.conf";
  };
}
