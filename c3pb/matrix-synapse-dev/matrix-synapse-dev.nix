{ pkgs, config, lib, ... }:
let
  srcPath = "/home/test/synapse";
  port = 8030;
in {
  config = {
    services.matrix-synapse = {
      enable = true;

      allow_guest_access  = false;
      enable_registration = false;
      url_preview_enabled = true;

      database_type = "sqlite3";

      server_name = "matrix-dev";
      public_baseurl = "https://${config.services.matrix-synapse.server_name}/";
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
              names = [ "client" ];
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
        use_presence: true
        enable_group_creation: true
        group_creation_prefix: "unofficial/"
        acme:
          enabled: false
      '';
      extraConfigFiles = [
        "${srcPath}/oidc-config.yaml"
      ];
    };
  };
}
