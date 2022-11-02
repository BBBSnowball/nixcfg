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
    yarnPreBuild = ''
      mkdir -p $HOME/.node-gyp/${nodejs.version}
      echo 9 > $HOME/.node-gyp/${nodejs.version}/installVersion
      ln -sfv ${nodejs}/include $HOME/.node-gyp/${nodejs.version}
      export npm_config_nodedir=${nodejs}
    '';
    pkgConfig = {
      mediasoup = {
        postInstall = ''
          #yarn --offline run worker:build
          #make -C worker PIP_BUILD_BINARIES='--no-binary :all:' MESON="$(which meson)" MESON_ARGS="-Dwrap_mode=nodownload \"\""
          mkdir -p worker/out/Release/
          cp ${mediasoup}/bin/mediasoup-worker worker/out/Release/
        '';
      };
      bcrypt = {
        nativeBuildInputs = with pkgs; [
          which
          (python3.withPackages (p: [ p.pip p.setuptools p.meson ]))
        ];
        buildInputs = [
          pkgs.nodePackages.node-gyp-build
          pkgs.nodePackages.node-pre-gyp
          nodejs
        ];
        postInstall = ''
          node-pre-gyp install --fallback-to-build --help
          #node-pre-gyp build
          rm -rf build-tmp-napi-v3
        '';
      };
    };
    buildPhase = ''
      cp -r $src/* .
      #yarn --offline build
      export PATH=$PATH:$node_modules/.bin
      tsc
      # Those are demo certs -> omit them
      #cp $src/certs -r dist/certs
      chmod 755 dist/server.js
    '';
    outputs = [ "out" "bin" ];
    postInstall = ''
      mkdir $bin/{bin,lib} -p
      cp -r dist $bin/lib/edumeet-server
      cp -r $out/libexec/edumeet-server/node_modules $bin/lib/edumeet-server/
      ln -s ../lib/edumeet-server/server.js $bin/bin/edumeet-server
      ln -s ../lib/edumeet-server/connect.js $bin/bin/edumeet-connect
    '';
    extraBuildInputs = with pkgs; [
      (python3.withPackages (p: [ p.pip p.setuptools p.meson ]))
      meson ninja
    ];
  };
}
