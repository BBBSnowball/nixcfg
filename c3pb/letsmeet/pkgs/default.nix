{pkgs ? import <nixpkgs> {
    inherit system;
  }, system ? builtins.currentSystem, nodejs ? pkgs."nodejs-14_x"}:

let
  nodeEnv = import ./node-env.nix {
    inherit (pkgs) stdenv python2 utillinux runCommand writeTextFile;
    inherit nodejs;
    libtool = if pkgs.stdenv.isDarwin then pkgs.darwin.cctools else null;
  };
  version = "3.4";
  edumeetSrc = pkgs.fetchFromGitHub {
    owner = "edumeet";
    repo  = "edumeet";
    # This isn't tagged 3.4 (probably not released, yet) but the commit message says "3.4".
    rev = "a83a27b72c4a812f5e008320f927f56092978b5b";
    sha256 = "1wm05wqmhymz5wslb2xqdk2v4s0hwr95bqlyymypxhihsmf82b70";
  };
  nodePackages = pkgs.nodePackages.override { inherit nodejs; };
  nodeEnvWithGyp = sources: with builtins; nodeEnv // {
    buildNodePackage = { buildInputs, dependencies, ... }@args: let
      extraDepsSources = filter (x: let name = pkgs.lib.getName x.name; in name == "node-pre-gyp" || name == "node-gyp-build") (attrValues sources);
      extraDeps = map (x: nodeEnv.buildNodePackage (x // { inherit dependencies; })) extraDepsSources;
    in nodeEnv.buildNodePackage (args // { buildInputs = buildInputs ++ extraDeps; });
  };
  blub = file: args: file (args // { nodeEnv = nodeEnvWithGyp (file args).sources; });
in
{
  src = edumeetSrc;
  inherit version nodejs;
  app = import ./node-packages-app.nix {
    inherit (pkgs) fetchurl fetchgit;
    inherit nodeEnv;
    inherit edumeetSrc;
  };
  server = blub (import ./node-packages-server.nix) {
    inherit (pkgs) fetchurl fetchgit runCommand;
    nodeEnv = nodeEnvWithGyp;
    inherit edumeetSrc;
  };
}
