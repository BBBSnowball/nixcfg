{ pkgs, config, lib, ... }:
let
  dingeSrc = pkgs.fetchgit {
    url = https://git.c3pb.de/c3pb/inventory;
    rev = "f230b875d70eafe8318f249059dda87f348884f6";
    sha256 = "0higbr624n2hshgp7h33dgm51w6ml556jfna4m0rq0hm7zlscqd1";
  };
  nodeDeps = (import ./dinge-info-dependencies {
    inherit pkgs;
    inherit (pkgs) nodejs;
    inherit (config) system;
  }).send;
in {
  users.users.dinge = {
    isNormalUser = false;
    home = "/home/dinge";
  };

  systemd.services.dinge-info = {
    after = ["network.target"];
    description = "Forwarding service for dinge.info";
    environment.CONFIG = "/etc/nixos/secret/dinge-info.js";
    environment.NODE_PATH = "${nodeDeps}/lib/node_modules";
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.nodejs}/bin/node dinge.js";
      WorkingDirectory = "${dingeSrc}";
      User = "dinge";
      Restart = "always";
      RestartSec = 10;
    };
  };

  networking.firewall.allowedTCPPorts = [4245];
}
