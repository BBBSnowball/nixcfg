{pkgs ? import <nixpkgs> {
    inherit system;
  }, system ? builtins.currentSystem, nodejs ? pkgs."nodejs-13_x"}:

let
  nodeEnv = import ./node-env.nix {
    inherit (pkgs) stdenv python2 utillinux runCommand writeTextFile;
    inherit nodejs;
    libtool = if pkgs.stdenv.isDarwin then pkgs.darwin.cctools else null;
  };
  version = "3.3";
  edumeetSrc = pkgs.fetchFromGitHub {
    owner = "edumeet";
    repo  = "edumeet";
    rev = version;
    sha256 = "098cs9z90ff8cgp88rqi2x79ma1s1a7w02mzzrix80z61ndinpnf";
  };
in
{
  src = edumeetSrc;
  inherit version;
  app = import ./node-packages-app.nix {
    inherit (pkgs) fetchurl fetchgit;
    inherit nodeEnv;
    inherit edumeetSrc;
  };
  server = import ./node-packages-server.nix {
    inherit (pkgs) fetchurl fetchgit runCommand;
    inherit nodeEnv;
    inherit edumeetSrc;
  };
}
