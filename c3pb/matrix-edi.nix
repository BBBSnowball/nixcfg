{ config, pkgs, lib, ... }:
let
  test = true;
  name = "matrix-edi";
  domain = lib.fileContents ../private/trueDomain.txt;

  python = pkgs.python3.withPackages (p: with p; [matrix-client amqplib]);
  src = pkgs.fetchgit {
    url = "https://git.c3pb.de/edi/edi-bot-matrix";
    rev = "12346b47115300d6593ed3464385cbd13e8553a4";
    sha256 = "0rk3g9rh2d9vrrj45abgnnbib6m968wng6r92kp2an2rlz2dhhak";
  };

  botConfig = pkgs.writeText"matrix-edi-config" ''
    import os

    config = {
        "matrixurl" : "http://localhost:8008",
        "username": "edibot",
        "passwd" : "",
        "broadcastActionChannels": [
            ${(import ../private/matrix-channel-ids.nix).spielwiese},
            ${(import ../private/matrix-channel-ids.nix).subraum},
        ],
        #FIXME remove?
        "channels" : {"_channel_" : "#subraum",
                      "_c3pb_"    : "#c3pb"},
    }

    config["channel-aliases"] = { v : k for k, v in config["channels"].items() }

    AMQP_SERVER = os.getenv("AMQP_SERVER") or "localhost"

    with open("/var/lib/${name}/authtoken", "r") as f:
      config["token"] = f.read().strip()
  '';

  matrixHomeserverDatabase = "${config.services.matrix-synapse.dataDir}/homeserver.db";
  initScript = pkgs.writeShellScript "${name}-init" ''
    set -e
    chmod 700 .
    if ! [ -e authtoken ] ; then
      umask 077
      ${pkgs.sqlite}/bin/sqlite3 ${matrixHomeserverDatabase} "select token from access_tokens where user_id='@edibot:test.${domain}'" >authtoken.tmp
      if [ -z "$(cat authtoken.tmp)" ] ; then
        pw=$(${pkgs.pwgen}/bin/pwgen -s1 42)
        echo -e "$pw\n$pw" | ${pkgs.matrix-synapse}/bin/register_new_matrix_user -u edibot --no-admin -c /etc/nixos/secret/matrix-synapse/homeserver-secret.yaml
      fi
      ${pkgs.sqlite}/bin/sqlite3 ${matrixHomeserverDatabase} "select token from access_tokens where user_id='@edibot:test.${domain}'" >authtoken.tmp
      if [ -n "$(cat authtoken.tmp)" ] ; then
        mv authtoken.tmp authtoken
        chmod 400 authtoken
        chown ${name} authtoken
      else
        echo "Couldn't register user or get auth token" >&2
        exit 1
      fi
    fi
    ln -sfn ${botConfig} config.py
    rm -rf __pycache__
  '';
in {
  users.users."${name}" = {
    isNormalUser = false;
  };

  systemd.services."${name}" = {
    after = ["network.target" "matrix-synapse.service"];
    description = "EDI bot for Matrix";
    environment.PYTHONPATH = "${src}:${src}/python-matrix-bot-api:/var/lib/${name}";
    serviceConfig = {
      Type = "simple";
      ExecStartPre = "+${pkgs.bash}/bin/bash ${initScript}";
      ExecStart = "${python}/bin/python ${src}/matrix_edi.py";
      WorkingDirectory = "/var/lib/${name}";
      StateDirectory = "${name}";
      User = "${name}";
      Restart = "always";
      RestartSec = 10;
    };
    restartTriggers = [src python];
  };
}
