{ config, pkgs, lib, ... }:
let
  test = true;
  name = "matrix-edi";

  python = pkgs.python3.withPackages (p: with p; [matrix-client amqplib]);
  src = pkgs.fetchgit {
    url = "https://${(import ../private/deploy-tokens.nix).matrix-edi}@git.c3pb.de/edi/edi-bot-matrix";
    rev = "cf7c4d800026cd10e15854ef8fb1c05224480f51";
    sha256 = "1ylwk8ipqikjzxspdgqf9cpswwgvq5xhb8si9828smpq0h3l5lg5";
  };
  #src = "/tmp/matrix-edi";

  matrixConfig = config.services.matrix-synapse;
  matrixServerName = matrixConfig.server_name;
  matrixServerDatabase = "${matrixConfig.dataDir}/homeserver.db";
  botName = "edibot";
  botUserId = "@${botName}:${matrixServerName}";
  botConfig = pkgs.writeText"matrix-edi-config" ''
    import os

    config = {
        "matrixurl" : "http://localhost:8008",
        "username": "${botName}",
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
      config["user_id"] = "${botUserId}";
  '';

  initScript = pkgs.writeShellScript "${name}-init" ''
    set -e
    chmod 700 .
    if ! [ -e authtoken ] ; then
      umask 077
      ${pkgs.sqlite}/bin/sqlite3 ${matrixServerDatabase} "select token from access_tokens where user_id='${botUserId}'" >authtoken.tmp
      if [ -z "$(cat authtoken.tmp)" ] ; then
        pw=$(${pkgs.pwgen}/bin/pwgen -s1 42)
        echo -e "$pw\n$pw" | ${pkgs.matrix-synapse}/bin/register_new_matrix_user -u ${botName} --no-admin -c /etc/nixos/secret/matrix-synapse/homeserver-secret.yaml
      fi
      ${pkgs.sqlite}/bin/sqlite3 ${matrixServerDatabase} "select token from access_tokens where user_id='${botUserId}'" >authtoken.tmp
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
