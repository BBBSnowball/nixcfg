privateForHost: self: super:
let
  nodejs = self.nodejs_18;
  edumeet = import ./pkgs { pkgs = self; inherit nodejs; };
  configApp = ./config.app.js;
  configServer  = import ../substitute.nix self ./config.server.js "--replace @serverExternalIp@ ${privateForHost.serverExternalIp}";
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
    name = "edumeet-server";
    inherit (edumeet) version src;
    package = edumeet.server;
    node_modules = package.node_modules;
    inherit (self) bash;
    app = self.edumeet-app;
    config = configServer;

    buildInputs = [ nodejs package ];

    buildPhase = "";

    installPhase = ''
      mkdir -p $out/{bin,lib/edumeet-server}

      cd $out/lib/edumeet-server
      cp -r $src/server/* .
      chmod +w config
      rm config/config.example.js
      # config uses require with relative paths so symlink won't work
      cp $config config/config.js
      ln -sfd $app public

      ln -sfd $node_modules node_modules

      ln -s ../lib/edumeet-server/server.js $out/bin/edumeet-server
      ln -s ../lib/edumeet-server/connect.js $out/bin/edumeet-connect
    '';
  };
}
