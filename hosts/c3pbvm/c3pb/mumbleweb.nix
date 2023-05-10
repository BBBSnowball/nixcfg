{ pkgs, config, lib, privateForHost, secretForHost, ... }:
let
  domain = privateForHost.mumble-domain-c3pb;

  #FIXME build this with Nix
  mumbleWebDist = pkgs.stdenv.mkDerivation {
    name = "mumble-web-dist";
    src = ./mumble-web-dist.tar;
    phases = ["extractPhase"];
    extractPhase = ''
      mkdir $out
      tar -C $out -xf $src
    '';
  };
in {
  users.users.mumbleweb = {
    isNormalUser = false;
    home = "/home/mumble";
  };

  systemd.services.mumble-web = {
    after = ["network.target"];
    description = "Web-UI for Mumble";
    environment.OPENSSL_CONF = ./mumbleweb-openssl.cnf;
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.pythonPackages.websockify}/bin/websockify --ssl-target --web=${mumbleWebDist} --cert=server.crt --key=server.key 64737 ${domain}:64738";
      RuntimeDirectory = "mumbleweb";
      ExecStartPre = [
        #NOTE untested!
        "!${pkgs.coreutils}/bin/install -m 0700 -o mumbleweb -d /run/mumbleweb/keys"
        "!${pkgs.coreutils}/bin/cp ${secretForHost}/mumble-web/ /run/mumbleweb/keys"
      ];
      WorkingDirectory = "/run/mumbleweb/keys";
      User = "mumbleweb";
      Restart = "always";
      RestartSec = 10;
    };
    wantedBy = [ "multi-user.target" ];
  };
}
