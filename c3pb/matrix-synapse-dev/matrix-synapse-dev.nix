{ pkgs, config, lib, ... }:
let
  srcPath = "/home/test/synapse";
  port = 8030;
  webclientSrc = pkgs.fetchzip {
    url = "https://github.com/vector-im/riot-web/releases/download/v1.6.7/riot-v1.6.7.tar.gz";
    sha256 = "1a5rvqw7n41887b30hxv30v8a5q8pc8p83bqklf86mrq09hb2nn6";
  };
  webclientConfig = pkgs.writeText "riot-config.json" (lib.generators.toJSON {} {
    default_server_config."m.homeserver" = {
      base_url    = config.services.matrix-synapse.public_baseurl;
      server_name = config.services.matrix-synapse.server_name;
    };
  });
  webclientWithConfig = pkgs.runCommand "riot" {} ''
    mkdir $out
    ln -s ${webclientSrc}/* $out/
    ln -s ${webclientConfig} $out/config.json
  '';
in {
  config = {
    services.matrix-synapse = {
      enable = true;

      allow_guest_access  = false;
      enable_registration = false;

      database_type = "sqlite3";

      server_name = "matrix-dev";
      public_baseurl = "http://${config.services.matrix-synapse.server_name}:${toString port}/";
      listeners = [
        {
          bind_address = "";
          port = port;
          tls = false;
          type = "http";
          x_forwarded = true;
          resources = [
            {
              compress = true;
              names = [ "client" "webclient" ];
            }
            {
              compress = false;
              names = [ "federation" ];
            }
          ];
        }
        { bind_address = "127.0.0.1"; port = port+1; type = "manhole"; resources = []; }
      ];
      no_tls = true;

      extraConfig = ''
        suppress_key_server_warning: true
        web_client_location: ${webclientWithConfig}
      '';
      extraConfigFiles = [
        "${srcPath}/oidc-config.yaml"
      ];
    };
  };
}
