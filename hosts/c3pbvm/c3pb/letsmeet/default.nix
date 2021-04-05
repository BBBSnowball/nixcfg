{ config, pkgs, lib, ... }:
let
  pkg = pkgs.edumeet-server;
in {
  nixpkgs.overlays = [ (import ./overlay.nix) ];
  # make edumeet-connect available to the user
  environment.systemPackages = [ pkg ];

  networking.firewall.allowedTCPPorts = [ 8030 ];
  networking.firewall.allowedUDPPortRanges = [ { from = 40000; to = 40999; } ];

  services.redis = {
    enable = true;
    bind = "127.0.0.1";
    port = 0;
    unixSocket = "/run/redis/redis.sock";
    extraConfig = ''
      unixsocketperm 770
    '';
  };

  users.groups.redis-access = { };
  users.users.redis.group = "redis-access";
  users.groups.edumeet = { };

  users.users.edumeet = {
    description = "User for edumeet/multiparty-meeting server";
    isSystemUser = true;
    group = "edumeet";
    extraGroups = [ "redis-access" "redis" ];
  };

  systemd.services.edumeet = {
    description = "WebRTC meeting service (edumeet / multiparty-meeting)";

    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      ExecStart = "${pkg}/bin/edumeet-server";
      WorkingDirectory = "${pkg}/lib/edumeet-server";
      User = "edumeet";
      PermissionsStartOnly = true;
    };

    preStart = ''
      install -d /etc/edumeet /etc/edumeet/server.config.d
      if [ ! -e /etc/edumeet/server.config.d/cookieSecret.js ] ; then
        umask 077
        echo "module.exports = (function (config) { config.cookieSecret = '$(dd if=/dev/urandom bs=1 count=32 | base64 -w0)'; })" >/etc/edumeet/server.config.d/cookieSecret.js
        chgrp edumeet /etc/edumeet/server.config.d/cookieSecret.js
        chmod 740 /etc/edumeet/server.config.d/cookieSecret.js
      fi
    '';
  };
}
