{ pkgs, config, lib, ... }:
let
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
    environment.OPENSSL_CONF = "/etc/nixos/c3pb-mumbleweb-openssl.cnf";
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.pythonPackages.websockify}/bin/websockify --ssl-target --web=${mumbleWebDist} --cert=server.crt --key=server.key 64737 ${lib.fileContents ./private/mumble-domain-c3pb.txt}:64738";
      #WorkingDirectory = "/home/mumble";
      WorkingDirectory = "/etc/nixos/secret-mumble-web";
      User = "mumbleweb";
      Restart = "always";
      RestartSec = 10;
    };
  };
}
