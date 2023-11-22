privateForHost: self: super:
let
  nodejs = self.nodejs_16;
  edumeet = import ./pkgs { pkgs = self; inherit nodejs; };
  configApp = ./config.app.js;
  configServer  = import ../substitute.nix self ./config.server.js
    "--replace @serverExternalIp@ ${privateForHost.serverExternalIp} --replace @trueDomain@ ${privateForHost.trueDomain}";
  configServer2 = import ../substitute.nix self ./config.server.toml
    "--replace @serverExternalIp@ ${privateForHost.serverExternalIp} --replace @trueDomain@ ${privateForHost.trueDomain}";
in {
  edumeet-app = self.stdenv.mkDerivation rec {
    passthru.edumeet = edumeet;
    name = "edumeet-app-web";
    inherit (edumeet) version src;
    package = edumeet.app;
    #node_modules = "${package}/lib/node_modules/edumeet/node_modules";
    node_modules = package.node_modules;
    config = configApp;

    buildInputs = [ nodejs package ];

    buildPhase = ''
      cd app

      # react-scripts doesn't want to use NODE_PATH so we use one of the
      # preferred alternatives.
      # -> It doesn't like that we also have a tsconfig.json.
      #echo '{"compilerOptions": {"baseUrl": "node_modules"}}' >jsconfig.json

      #ln -s $node_modules
      # react wants to put a cache into node_modules/.cache
      mkdir node_modules
      cp -rs $node_modules/* node_modules/

      rm public/config/config.example.js
      ln -s $config public/config/config.js

      export PATH=$PATH:$node_modules/.bin

      # workaround, see here: https://github.com/nodejs/node/issues/40455
      export NODE_OPTIONS=--openssl-legacy-provider

      react-scripts build
    '';

    installPhase = ''
      cp -r build $out
    '';
  };

  edumeet-server = self.stdenv.mkDerivation rec {
    passthru.edumeet = edumeet;
    passthru.nodejs = nodejs;
    name = "edumeet-server";
    inherit (edumeet) version src;
    package = edumeet.server;
    node_modules = package.node_modules;
    inherit (self) bash;
    app = self.edumeet-app;
    config = configServer;
    config2 = configServer2;

    buildInputs = [ nodejs package ];
    nativeBuildInputs = [ self.typescript ];

    buildPhase = ''
      # config uses require with relative paths so symlink won't work
      #rm server/config/config.example.*
      cp $config server/config/config.js
      cp $config2 server/config/config.toml
      ln -sfT $app server/public

      ln -sfT $node_modules server/node_modules
      ( cd server && tsc )
      chmod +x server/dist/*.js

      ln -sfT $app server/dist/public
      cp $config2 server/dist/config/config.toml
    '';

    installPhase = ''
      mkdir -p $out/{bin,lib/edumeet-server}

      cp -r ./server/* $out/lib/edumeet-server/

      ln -s ../lib/edumeet-server/dist/server.js $out/bin/edumeet-server
      ln -s ../lib/edumeet-server/dist/connect.js $out/bin/edumeet-connect
    '';
  };
}
