#!/bin/sh -e
XDG_RUNTIME_DIR=/run/user/$UID exec nix-shell -E 'let p = import <nixpkgs> {}; in p.stdenv.mkDerivation {name="a"; buildInputs=[(p.python3.withPackages (p: with p; [cherrypy]))];}' --run "python3 main.py"
