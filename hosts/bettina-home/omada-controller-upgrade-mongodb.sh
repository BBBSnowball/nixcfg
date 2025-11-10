#!/usr/bin/env bash
set -eo pipefail

# We have to upgrade from MMAPv1 format to WiredTiger to use newer MongoDB.
# see https://www.mongodb.com/docs/manual/tutorial/change-standalone-wiredtiger/

datadir=/var/lib/omada-controller

case "$(whoami)" in
  root)
    #nix build /etc/nixos/flake#inputs.routeromen.inputs.nixpkgs-mongodb.legacyPackages.x86_64-linux.mongodb -o $datadir/mongodb-legacy
    nix build /etc/nixos/flake#mongodb-legacy -o $datadir/mongodb-legacy
    #nix build nixpkgs#mongodb -o $datadir/mongodb-current
    nix build /etc/nixos/flake#mongodb-new-unfree-sspl -o $datadir/mongodb-current
    nix build nixpkgs#mongodb-tools -o $datadir/mongodb-tools
    exec su omada-controller -s "$(which bash)" -c "$0 $@"
    ;;

  omada-controller)
    cd /var/lib/omada-controller/data
    ../mongodb-legacy/bin/mongod --port 27017 --dbpath ../data/db -pidfilepath ../data/mongo.pid --bind_ip 127.0.0.1 &
    ../mongodb-tools/bin/mongodump --out=../backup-mmapv1
    kill "$(cat ../data/mongo.pid)"

    exit 42  ;#FIXME
    #./mongodb-current/bin/mongod --port 27218 --dbpath ../data/db-new -pidfilepath ../data/mongo-new.pid --logappend --logpath ../logs/mongod-new.log --setParameter tcmallocReleaseRate=5.0 --setParameter tcmallocAggressiveMemoryDecommit=1 --bind_ip 127.0.0.1 &
    ;;

  *)
    echo "Error: Cannot do anything for that user!" >&2
    exit 1
    ;;
esac

