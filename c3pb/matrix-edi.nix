{ config, pkgs, lib, ... }:
let
  test = true;
  name = "matrix-edi";

  #NOTE user must be created in Synapse:
  #     /nix/store/mzzk8aq11fh8mvksgffkn6a3xzf71xl1-matrix-synapse-1.14.0/bin/register_new_matrix_user -u edibot --no-admin -c matrix-synapse/homeserver-secret.yaml

  python = pkgs.python3.withPackages (p: with p; [matrix-client amqplib]);
  src = pkgs.fetchgit {
    url = "https://git.c3pb.de/edi/edi-bot-matrix";
    rev = "12346b47115300d6593ed3464385cbd13e8553a4";
    sha256 = "0rk3g9rh2d9vrrj45abgnnbib6m968wng6r92kp2an2rlz2dhhak";
  };
in {
  users.users."${name}" = {
    isNormalUser = false;
  };

  systemd.services."${name}" = {
    after = ["network.target" "matrix-synapse.service"];
    description = "EDI bot for Matrix";
    environment.PYTHONPATH = "${src}:${src}/python-matrix-bot-api:/etc/nixos/secret/${name}";
    serviceConfig = {
      Type = "simple";
      ExecStart = "${python}/bin/python ${src}/matrix_edi.py";
      User = "${name}";
      Restart = "always";
      RestartSec = 10;
    };
    restartTriggers = [src python];
  };
}
