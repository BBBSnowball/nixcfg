{ pkgs, config, lib, ... }:
let
  dingeSrc = pkgs.fetchgit {
    url = https://git.c3pb.de/c3pb/inventory;
    rev = "de947d0837a5c309d875918cf1a31720e33b2105";
    sha256 = "01lw25q9cfrjr289jqinx2x79abi25ssxa9hgw2g9fd0p8hjkgax";
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
    environment.CONFIG = "/etc/nixos/secret-dinge-info.js";
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
}
