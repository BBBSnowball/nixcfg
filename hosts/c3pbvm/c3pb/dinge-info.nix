{ pkgs, config, lib, private, ... }:
let
  dingeSrc = pkgs.fetchgit {
    url = "https://${(import "${private}/deploy-tokens.nix").inventory}@git.c3pb.de/c3pb/inventory";
    rev = "f230b875d70eafe8318f249059dda87f348884f6";
    sha256 = "0higbr624n2hshgp7h33dgm51w6ml556jfna4m0rq0hm7zlscqd1";
  };
  nodejs = pkgs."nodejs-14_x";
  nodeDeps = (import ./dinge-info-dependencies {
    inherit pkgs nodejs;
    inherit (config) system;
  }).send;
in {
  users.users.dinge = {
    isSystemUser = true;
    home = "/home/dinge";
    group = "dinge";
  };
  users.groups.dinge = {};

  systemd.services.dinge-info = {
    after = ["network.target"];
    description = "Forwarding service for dinge.info";
    environment.CONFIG = "/etc/nixos/secret/dinge-info.js";
    environment.NODE_PATH = "${nodeDeps}/lib/node_modules";
    serviceConfig = {
      Type = "simple";
      ExecStart = "${nodejs}/bin/node dinge.js";
      WorkingDirectory = "${dingeSrc}";
      User = "dinge";
      Restart = "always";
      RestartSec = 10;
    };
    wantedBy = [ "multi-user.target" ];
  };

  networking.firewall.allowedTCPPorts = [4245];
}
