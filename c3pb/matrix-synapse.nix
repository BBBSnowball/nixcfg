{ pkgs, config, lib, ... }:
let
  isTestInstance = config.services.matrix-synapse.isTestInstance;
  portOffset = if isTestInstance then 1 else 0;
  domainTestPrefix = if isTestInstance then "test." else "";
  domain = lib.fileContents ../private/trueDomain.txt;
in {
  options = with lib; {
    services.matrix-synapse = {
      isTestInstance = mkOption {
        type = types.bool;
        description = "use config for test server if true, i.e. other port and domain";
      };
      localPort = mkOption {
        type = types.int;
        description = "port for local connections";
      };
    };
  };

  config = {
    nixpkgs.overlays = [
      (import ./matrix-synapse-update.nix)
    ];

    # add both ports because firewall will not be applied in the container
    networking.firewall.allowedTCPPorts = [ 8008 8009 ];

    services.matrix-synapse = {
      enable = true;

      allow_guest_access  = false;
      enable_registration = false;
      url_preview_enabled = true;

      dataDir = lib.mkIf (!isTestInstance) "/var/data/matrix-synapse";
      database_type = "sqlite3";

      server_name = "${domainTestPrefix}${domain}";
      public_baseurl = "https://${config.services.matrix-synapse.server_name}/";
      localPort = 8008+portOffset;
      listeners = [
        {
          bind_address = "";
          port = 8008+portOffset;
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
        { bind_address = "127.0.0.1"; port = 9000+portOffset; type = "manhole"; resources = []; }
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
        "/etc/nixos/secret/matrix-synapse/homeserver-secret.yaml"
        "/etc/nixos/secret/matrix-synapse/oidc-config.yaml"
      ];
      app_service_config_files = [
        #"/etc/matrix-synapse/matrix_irc_hackint.yaml"
        (if isTestInstance
          then "/etc/nixos/secret/matrix-synapse/mautrix-telegram-test.yaml"
          else "/etc/nixos/secret/matrix-synapse/mautrix-telegram.yaml")
      ];
    };

    systemd.services.matrix-synapse.restartTriggers = with config.services.matrix-synapse; extraConfigFiles ++ app_service_config_files;
  };
}
