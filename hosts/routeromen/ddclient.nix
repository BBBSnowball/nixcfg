{ config, pkgs, lib, secretForHost, ... }:
let
  ddclient-with-curl = pkgs.ddclient.overrideAttrs (_: { CURL = "${lib.getBin pkgs.curl}/bin/curl"; });
in
{
  services.ddclient = {
    enable = true;
    configFile = "${secretForHost}/ddclient.conf";
    # curl=yes is needed as a workaround for Perl issues in version 3.10 ("unexpected status") so we have to add curl
    package = ddclient-with-curl;
  };

  # The NixOS service uses ExecStartPre (or preStart) to install the config to the services run directory. We do the same but make sure
  # that it is only readable for the service. This may be a bit too paranoid.
  systemd.services.ddclient.serviceConfig.LoadCredential = "config:${config.services.ddclient.configFile}";
  systemd.services.ddclient.serviceConfig.ExecStartPre = lib.mkForce ''${lib.getBin pkgs.bash}/bin/bash -c "${lib.getBin pkgs.coreutils}/bin/ln -s $CREDENTIALS_DIRECTORY/config /run/ddclient/ddclient.conf"'';

  # curl=yes is needed as a workaround for Perl issues in version 3.10 ("unexpected status") so we have to add curl
  #systemd.services.ddclient.path = [ pkgs.curl pkgs.which ];
  # -> not enough -> We have to patch the ddclient package, see above.
}
