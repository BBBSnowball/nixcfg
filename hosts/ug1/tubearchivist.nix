{ pkgs, secretForHost, ... }:
let
  name = "tubearchivist";
  port = 8001;  # 8000 is already used by audiobookshelf

  src = pkgs.fetchFromGitHub {
    owner = "tubearchivist";
    repo = name;
    rev = "v0.5.1";
    hash = "sha256-emKicAM7gWvKTaDEYxJubDiwGzfmfPNTVoqJ1bkWldg=";
  };
in
{
  users.users.${name} = {
    isNormalUser = true;
    group = name;

    home = "/media/sdata/${name}";
    createHome = true;

    extraGroups = [ "podman" ];
    packages = with pkgs; [
      podman-tui
      podman-compose
    ];

    # podman needs the user session
    linger = true;
  };
  users.groups.${name} = { };

  # Transfer volumes from user to tubearchivist:
  # machinectl shell user@
  #   for x in es redis media cache ; do ( set -x; podman volume export tubearchivist_tubearchivist-$x -o volume-$x.tar ) ; done
  # mv ~user/tubearchivist/volume-* ~tubearchivist
  # machinectl shell tubearchivist@
  #   for x in es redis media cache ; do ( set -x; podman volume create tubearchivist_$x; podman volume import tubearchivist_$x volume-$x.tar ) ; done
  # cd ~tubearchivist/.local/share/containers/storage/volumes/tubearchivist_es
  # ls -ld _data _data/*
  # chown 166535 _data

  networking.firewall.allowedTCPPorts = [ port ];

  systemd.services.${name} = {
    description = "Tube Archivist Youtube library";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    path = with pkgs; [
      podman
      podman-compose
    ];

    environment.TA_HOST = "http://192.168.178.42:${toString port}";
    environment.PORT = toString port;
    environment.TZ = "Europe/Berlin";
    environment.REDIS_VERSION = "7.4.3";  # latest tag at time of writing

    preStart = ''
      set -eo pipefail

      # podman needs newuidmap
      PATH="/run/wrappers/bin:$PATH"

      # pull images in advance, so we can better control the version
      for img in \
        docker.elastic.co/elasticsearch/elasticsearch:8.17.2 \
        docker.io/library/redis:$REDIS_VERSION               \
        docker.io/library/node:lts-alpine                    \
        docker.io/library/python:3.11.8-slim-bookworm
      do
        if [ -z "$(podman images -q "$img")" ] ; then
          ( set -x; podman pull "$img" )
        fi
      done

      # build tubearchivist image from Dockerfile (i.e. let's not trust the registry here)
      if [ -z "$(podman images -q "localhost/tubearchivist")" ] ; then
        ( set -x; podman build ${src} --tag ${name} --pull=never )
      fi
    '';

    serviceConfig = {
      User = name;
      Group = name;
      # contains TA_PASSWORD and ELASTIC_PASSWORD
      EnvironmentFile = "${secretForHost}/tubearchivist.env";

      # `podman build` will take a while.
      TimeoutStartSec = "10min";

      WorkingDirectory = ./tubearchivist;
      #ExecStartPre = "${pkgs.podman}/bin/podman build ${src} --tag ${name}";
      ExecStart = "${pkgs.podman-compose}/bin/podman-compose up";
      ExecStop = "${pkgs.podman-compose}/bin/podman-compose down";
    };
  };
}
