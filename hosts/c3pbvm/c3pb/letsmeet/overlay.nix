private: self: super:
let
  nodejs = self.nodejs-16_x;
  edumeet = import ./pkgs { pkgs = self; inherit nodejs; };
  configApp = ./config.app.js;
  configServer  = import ../substitute.nix self ./config.server.js "--replace @serverExternalIp@ ${self.lib.fileContents "${private}/serverExternalIp.txt"}";
in {
  edumeet-app = self.stdenv.mkDerivation rec {
    name = "edumeet-app-web";
    inherit (edumeet.app.package) version;
    inherit (edumeet) src app;
    inherit (edumeet.app) node_modules;
    passthru.withoutConfig = edumeet.app;
    config = configApp;

    buildInputs = [ nodejs ];

    buildPhase = ''
      cd app

      # react-scripts doesn't want to use NODE_PATH so we use one of the
      # preferred alternatives.
      #echo '{"compilerOptions": {"baseUrl": "node_modules"}}' >jsconfig.json
      #ln -s $node_modules/edumeet/node_modules
      mkdir node_modules
      cp -sr $node_modules/* node_modules/

      rm public/config/config.example.js
      ln -s $config public/config/config.js

      export PATH=$PATH:$node_modules/.bin

      react-scripts build
    '';

    installPhase = ''
      cp -r build $out
    '';
  };

  edumeet-server = self.stdenv.mkDerivation rec {
    name = "edumeet-server";
    inherit (edumeet.server.package) version;
    inherit (edumeet) src server;
    inherit (self) bash;
    passthru.withoutConfig = edumeet.server;
    passthru.mediasoup = edumeet.mediasoup;
    app = self.edumeet-app;
    config = configServer;

    buildInputs = [ nodejs ];

    buildPhase = "";

    installPhase = ''
      mkdir -p $out
      cp -r $server/{bin,libexec} $out/

      dir=$out/libexec/edumeet-server/deps/edumeet-server
      chmod +w $dir $dir/config

      # config uses require with relative paths so symlink won't work
      cp $config $dir/config/config.js
      ln -sfd $app $dir/public

      #ln -s ../libexec/edumeet-server/node_modules/edumeet-server/server.js $out/bin/edumeet-server
      #ln -s ../libexec/edumeet-server/node_modules/edumeet-server/connect.js $out/bin/edumeet-connect
    '';
  };
}
