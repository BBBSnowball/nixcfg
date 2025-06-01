{ config, pkgs, lib, privateForHost, nixpkgsLetsmeet, ... }:
let
  useOldNixpkgs = true;

  overlays = [ (import ./overlay.nix privateForHost) ];
  # edumeet wants NodeJS 16 but NixOS refuses to evaluate it
  nixconfig.permittedInsecurePackages = [
    pkg.passthru.nodejs.name
  ];


  pkgs2 = if useOldNixpkgs
  then import nixpkgsLetsmeet {
    inherit overlays;
    system = pkgs.system;
    config = nixconfig;
  }
  else pkgs;
  pkg = pkgs2.edumeet-server;
in {
  nixpkgs.overlays = lib.mkIf (!useOldNixpkgs) overlays;
  # make edumeet-connect available to the user
  environment.systemPackages = [ pkg ];

  nixpkgs.config = nixconfig;

  networking.firewall.allowedTCPPorts = [ 8030 ];
  networking.firewall.allowedUDPPortRanges = [ { from = 40000; to = 40999; } ];

  services.redis.servers."" = {
    enable = true;
    bind = "127.0.0.1";
    port = 0;
    unixSocket = "/run/redis/redis.sock";
    settings.unixsocketperm = lib.mkForce "770";  # edumeet should be able to connect
  };

  users.groups.redis-access = { };
  users.users.redis.extraGroups = [ "redis-access" ];
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
    after = [ "network.target" "redis.service" ];

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

      if [ ! -e /etc/edumeet/cert/fullchain.pem ] ; then
        umask 077
        install -d /etc/edumeet/cert -g edumeet -m 0750
        cd /etc/edumeet/cert

        # https://opensource.docs.scylladb.com/stable/operating-scylla/security/generate-certificate.html
        # https://superuser.com/questions/126121/how-to-create-my-own-certificate-chain
        export PATH=${pkgs.openssl}/bin:$PATH
        openssl genrsa -out cadb.key 4096
        #openssl req -x509 -new -nodes -key cadb.key -days 3650 -config db.cfg -out cadb.pem
        openssl req -x509 -new -nodes -key cadb.key -days 3650 -out cadb.pem -subj "/C=US/ST=Utah/L=Provo/O=ACME Signing Authority Inc/CN=example.com"
        openssl genrsa -out db.key 4096
        #openssl req -new -key db.key -out db.csr -config db.cfg
        openssl req -new -key db.key -out db.csr -subj "/C=US/ST=Utah/L=Provo/O=ACME Tech Inc/CN=example.com"
        openssl x509 -req -in db.csr -CA cadb.pem -CAkey cadb.key -CAcreateserial -out db.crt -days 3650 -sha256
        cat db.crt cadb.pem > fullchain.pem
        chgrp -R edumeet .
        chmod 740 fullchain.pem db.key
      fi
    '';

    #environment.DEBUG = "edumeet:*,config:*,config";
    environment.DEBUG = "*";
    environment.DEBUG_COLORS = "1";
    environment.DEBUG_DEPTH = "5";
    #NOTE Same thing for the client: `window.localStorage.setItem('debug', '*');`
  };
}
