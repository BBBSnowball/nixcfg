{ pkgs, config, lib, ... }:
let
  dingeSrc = pkgs.fetchgit {
    url = https://git.c3pb.de/c3pb/inventory;
    rev = "de947d0837a5c309d875918cf1a31720e33b2105";
    sha256 = "01lw25q9cfrjr289jqinx2x79abi25ssxa9hgw2g9fd0p8hjkgax";
  };
  # The dependencies have been generated with node2nix with a fake package.json.
  # We should probably use `node2nix --input <( echo "[\"$1\"]")` but I don't
  # know how to use the result (except with nix-env - which is certainly not
  # what I want).
  nodeShell = import ./dinge-info-dependencies {
    inherit pkgs;
    inherit (pkgs) nodejs;
    inherit (config) system;
  };
in {
  users.users.dinge = {
    isNormalUser = false;
    home = "/home/dinge";
  };

  systemd.services.dinge-info = {
    after = ["network.target"];
    description = "Forwarding service for dinge.info";
    environment.CONFIG = "/etc/nixos/secret-dinge-info.js";
    serviceConfig = {
      Type = "simple";
      #ExecStart = "${pkgs.nodejs}/bin/node dinge.js";
      ExecStart = "${nodeShell.shell}/bin/shell -c '${pkgs.nodejs}/bin/node dinge.js'";
      WorkingDirectory = "${dingeSrc}";
      User = "dinge";
      Restart = "always";
      RestartSec = 10;
    };
  };
}
