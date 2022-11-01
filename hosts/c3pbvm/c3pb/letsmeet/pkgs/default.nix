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
rec {
  src = edumeetSrc;
  inherit version nodejs;
  app = pkgs.mkYarnPackage {
    name = "edumeet";
    src = "${edumeetSrc}/app";
    packageJSON = "${edumeetSrc}/app/package.json";
    yarnLock = "${edumeetSrc}/app/yarn.lock";
    yarnNix = ./yarn-app.nix;
  };
  server1 = pkgs.mkYarnPackage {
    name = "edumeet";
    src = "${edumeetSrc}/server";
    packageJSON = "${edumeetSrc}/server/package.json";
    yarnLock = "${edumeetSrc}/server/yarn.lock";
    yarnNix = ./yarn-server.nix;
  };
  mediasoup = pkgs.stdenv.mkDerivation {
    name = "mediasoup";
    src = "${server1.node_modules}/mediasoup/worker";
    nativeBuildInputs = with pkgs; [ meson ninja pkg-config cmake ];
    buildInputs = with pkgs; [ openssl nlohmann_json abseil-cpp libuv srtp usrsctp catch2 ];
    patches = [ ./mediasoup-build.patch ];
    installPhase = ''
      meson install --tags mediasoup-worker
    '';
  };
  server = pkgs.mkYarnPackage {
    name = "edumeet";
    src = "${edumeetSrc}/server";
    packageJSON = "${edumeetSrc}/server/package.json";
    yarnLock = "${edumeetSrc}/server/yarn.lock";
    yarnNix = ./yarn-server.nix;
    pkgConfig = {
      mediasoup = {
        postInstall = ''
          #yarn --offline run worker:build
          #make -C worker PIP_BUILD_BINARIES='--no-binary :all:' MESON="$(which meson)" MESON_ARGS="-Dwrap_mode=nodownload \"\""
          mkdir -p worker/out/Release/bin/
          cp ${mediasoup}/bin/mediasoup-worker worker/out/Release/bin/
        '';
      };
    };
    buildPhase = ''
      cp -r $src/* .
      #yarn --offline build
      export PATH=$PATH:$node_modules/.bin
      tsc && ln -s ../certs dist/certs && chmod 755 dist/server.js && ( for fileExt in yaml json toml ; do [ -f config/config.$fileExt ] && cp config/config.$fileExt dist/config/ || true; done ) | true && touch 'dist/ __AUTO_GENERATED_CONTENT_REFRESHED_AFTER_REBUILDING!__ '
    '';
    postInstall = ''
      ln -s ../libexec/edumeet-server/node_modules/edumeet-server/server.js $out/bin/edumeet-server
      ln -s ../libexec/edumeet-server/node_modules/edumeet-server/connect.js $out/bin/edumeet-connect
    '';
    extraBuildInputs = with pkgs; [
      (python3.withPackages (p: [ p.pip p.setuptools p.meson ]))
      meson ninja
    ];
  };
}
