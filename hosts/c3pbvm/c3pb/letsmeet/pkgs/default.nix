{pkgs ? import <nixpkgs> {
    inherit system;
  }, system ? builtins.currentSystem, nodejs ? pkgs."nodejs-14_x"}:

let
  nodeEnv = pkgs.callPackage ./node-env.nix {
    #inherit nodejs pkgs;
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
  nodeEnvWithGyp = nodeEnv // {
    buildNodePackage = { buildInputs, ... }@args:
      nodeEnv.buildNodePackage (args // { buildInputs = buildInputs ++ [ nodePackages.node-pre-gyp ]; });
  };
in
{
  src = edumeetSrc;
  inherit version nodejs;
  app = pkgs.callPackage ./node-packages-app.nix {
    inherit nodeEnv;
    inherit edumeetSrc;
  };
  server = pkgs.callPackage ./node-packages-server.nix {
    nodeEnv = nodeEnvWithGyp;
    inherit edumeetSrc;
  };
}
