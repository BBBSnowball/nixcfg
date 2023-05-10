privateForHost: self: super:
let
  nodejs = self.nodejs-14_x;
  edumeet = import ./pkgs { pkgs = self; inherit nodejs; };
  configApp = ./config.app.js;
  configServer  = import ../substitute.nix self ./config.server.js "--replace @serverExternalIp@ ${privateForHost.serverExternalIp}";
in {
  edumeet-app = self.stdenv.mkDerivation rec {
    name = "edumeet-app-web";
    inherit (edumeet) version src;
    inherit (edumeet.app) package;
    config = configApp;

    buildInputs = [ nodejs package ];

    buildPhase = ''
      cd app

      # react-scripts doesn't want to use NODE_PATH so we use one of the
      # preferred alternatives.
      echo '{"compilerOptions": {"baseUrl": "node_modules"}}' >jsconfig.json
      ln -s $package/lib/node_modules/edumeet/node_modules

      rm public/config/config.example.js
      ln -s $config public/config/config.js

      export PATH=$PATH:$package/lib/node_modules/edumeet/node_modules/.bin

      react-scripts build
    '';

    installPhase = ''
      cp -r build $out
    '';
  };

  edumeet-server = self.stdenv.mkDerivation rec {
    name = "edumeet-server";
    inherit (edumeet) version src;
    inherit (edumeet.server) package;
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

      ln -sfd $package/lib/node_modules/edumeet-server/node_modules node_modules

      ln -s ../lib/edumeet-server/server.js $out/bin/edumeet-server
      ln -s ../lib/edumeet-server/connect.js $out/bin/edumeet-connect
    '';
  };
}
