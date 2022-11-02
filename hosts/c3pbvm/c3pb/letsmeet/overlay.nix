private: self: super:
let
  nodejs = self.nodejs-16_x;
  edumeet = import ./pkgs { pkgs = self; inherit nodejs; };
  configApp = ./config.app.js;
  configServer  = import ../substitute.nix self ./config.server.js "--replace @serverExternalIp@ ${self.lib.fileContents "${private}/serverExternalIp.txt"}";
  configServer2 = import ../substitute.nix self ./config.server.yaml "--replace @serverExternalIp@ ${self.lib.fileContents "${private}/serverExternalIp.txt"}";
in {
  # https://nixos.wiki/wiki/Node.js#Using_nodePackages_with_a_different_node_version
  # -> doesn't seem to have any effect on node-pre-gyp but would fail to build anyway
  #nodejs = self.nodejs-16_x;

  edumeet-app = self.stdenv.mkDerivation rec {
    name = "edumeet-app-web";
    inherit (edumeet.app.package) version;
    inherit (edumeet) src;
    inherit (edumeet.app) node_modules;
    passthru.app = edumeet.app;
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
    inherit (edumeet) src;
    inherit (self) bash;
    withoutConfig = edumeet.server.bin;
    passthru.mediasoup = edumeet.mediasoup;
    #passthru.serviceWorkingSubdirectory = "libexec/edumeet-server/node_modules/edumeet-server";
    passthru.serviceWorkingSubdirectory = "lib/edumeet-server";
    app = self.edumeet-app;
    config = configServer;
    config2 = configServer2;

    buildPhase = "";

    installPhase = ''
      mkdir -p $out
      cp -r $withoutConfig/* $out/

      #dir=$out/libexec/edumeet-server/deps/edumeet-server
      dir=$out/lib/edumeet-server
      chmod +w $dir $dir/config

      # config uses require with relative paths so symlink won't work
      cp $config $dir/config/config.js
      cp $config2 $dir/config/config.yaml

      ln -sfd $app $dir/public
      mkdir $dir/dist
      ln -sfd $app $dir/dist/public
    '';
  };
}
