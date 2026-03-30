{ lib, pkgs, config, domain, ports, privateForContainer, localAddress, ... }:
let
  # generate with: openssl rand -hex 64
  inherit (privateForContainer) fixmeMakeThisSecret;
in
{
  services.flohmarkt = {
    enable = true;
    configureCouchDb = true;  #FIXME remove later?
    language = "de_DE.UTF-8";
    port = ports.flohmarkt.port;

    #FIXME make them secret
    initialization.db_admin_pw = fixmeMakeThisSecret;
    initialization.db_user_pw = fixmeMakeThisSecret;
    initialization.setupCode = fixmeMakeThisSecret;

    settings.general = {
      instanceName = "Pader Treibgut";
      externalUrl = "https://${domain}";
      #dataPath = "/var/lib/flohmarkt";
    };

    settings.database = {
      useHttps = false;  #FIXME replace by Unix socket -> not supported by CouchDB
      password = fixmeMakeThisSecret;  #FIXME
    };

    settings.email = {
      from = "noreply@${domain}";
      #name = "Flohmarkt (do not reply)";
      mailMethod = "sendmail";
      sendmail.sendmailExecutable = "/run/current-system/sw/bin/sendmail";
    };

    settings.tilecache = {};

    #website = {
    #  enable = true;
    #  port = 8205;  #FIXME
    #  dataPath = "/var/lib/flohmarkt-website";
    #  url = "https://web.${domain}";
    #};
  };

  #FIXME disable debugging
  systemd.services.flohmarkt.environment.FLOHMARKT_DEBUG = "1";

  #FIXME The init service fails on first start because the DB doesn't know the user, yet. Can we fix this somehow?
  systemd.services.flohmarkt-init-db = {
    script = lib.mkBefore ''
      for _ in `seq 10` ; do
        # very insecure - but not more so than the other scripts
        #FIXME fix this anyway!
        url="http://admin:${config.services.flohmarkt.initialization.db_admin_pw}@localhost:1025/"
        if ! res="$(${pkgs.curl}/bin/curl -s "$url")" ; then
          echo "DB not available. Waiting a bit."
          sleep 1
        elif grep -qF '"error":"unauthorized"' <<<"$res" ; then
          echo "Admin user not authorized for DB. Waiting a bit."
          sleep 1
        else
          break
        fi
      done
    '';
  };

  #FIXME ugly hack: flohmarkt listens on localhost only because module.nix starts it with `--host localhost` -> forward to container IP
  systemd.services.portfwd = {
    requiredBy = [ "flohmarkt.service" ];
    serviceConfig.ExecStart = let
      port = ports.flohmarkt.port;
    in "${pkgs.socat}/bin/socat TCP-LISTEN:${toString port},bind=${localAddress},fork TCP-CONNECT:localhost:${toString port}";
  };

  # same thing for CouchDB - just for debugging!
  #FIXME disable later
  # use like this:
  # 1. ssh nixos -L 1025:192.168.7.2:1025
  # 2. open http://localhost:1025/_utils/
  systemd.services.portfwd2 = {
    requiredBy = [ "flohmarkt.service" ];
    serviceConfig.ExecStart = let
      port = 1025;
    in "${pkgs.socat}/bin/socat TCP-LISTEN:${toString port},bind=${localAddress},fork TCP-CONNECT:localhost:${toString port}";
  };
  networking.firewall.allowedTCPPorts = [ 1025 ];
}
