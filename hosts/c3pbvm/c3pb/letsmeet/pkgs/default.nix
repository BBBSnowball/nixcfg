{pkgs ? import <nixpkgs> {
    inherit system;
  }, system ? builtins.currentSystem, nodejs ? pkgs."nodejs-16_x"}:

let
  nodeEnv = pkgs.callPackage ./node-env.nix {
    #inherit nodejs pkgs;
    inherit nodejs;
    libtool = if pkgs.stdenv.isDarwin then pkgs.darwin.cctools else null;
  };
  version = "3.5.3";
  edumeetSrc = pkgs.fetchFromGitHub {
    owner = "edumeet";
    repo  = "edumeet";
    rev = "3.5.3";  # 5de2d1bf99456497ff8c33e7d024cd7ad9f33946
    sha256 = "sha256-m1mlBccAoTLFRFBVguY8D0rb0DGfQmhy3B+LCWi8xLE=";
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
    globalBuildInputs = with pkgs; [
      (python3.withPackages (p: [ p.pip p.setuptools p.meson ]))
      #meson ninja
    ];
  };
}
