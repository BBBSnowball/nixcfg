{ config, pkgs, lib, ... }:
{
  services.ddclient = {
    enable = true;
    configFile = "/etc/nixos/secret/by-host/${config.networking.hostName}/ddclient.conf";
  };

  # The NixOS service uses ExecStartPre (or preStart) to install the config to the services run directory. We do the same but make sure
  # that it is only readable for the service. This may be a bit too paranoid.
  systemd.services.ddclient.serviceConfig.LoadCredential = "config:${config.services.ddclient.configFile}";
  systemd.services.ddclient.serviceConfig.ExecStartPre = lib.mkForce ''${lib.getBin pkgs.bash}/bin/bash -c "${lib.getBin pkgs.coreutils}/bin/ln -s $CREDENTIALS_DIRECTORY/config /run/ddclient/ddclient.conf"'';
}
