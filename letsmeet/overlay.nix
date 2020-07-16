self: super:
let
  nodejs = self.nodejs-13_x;
  edumeet = import ./pkgs { pkgs = self; inherit nodejs; };
  configApp = ./config.app.js;
  configServer = ./config.server.js;
in {
  edumeet-app = self.stdenv.mkDerivation {
    name = "multiparty-meeting-app-generated";
    inherit (edumeet) version src;
    app = edumeet.app.package;
    config = configApp;

    buildInputs = [ nodejs edumeet.app.package ];

    buildPhase = ''
      cd app

      # react-scripts doesn't want to use NODE_PATH so we use one of the
      # preferred alternatives.
      echo '{"compilerOptions": {"baseUrl": "node_modules"}}' >jsconfig.json
      ln -s $app/lib/node_modules/multiparty-meeting/node_modules

      rm public/config/config.example.js
      ln -s $config public/config/config.js

      export PATH=$PATH:$app/lib/node_modules/multiparty-meeting/node_modules/.bin

      react-scripts build
    '';

    installPhase = ''
      cp -r build $out
    '';
  };
}
