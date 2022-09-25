{ pkgs, config, lib, private, ... }:
let
  isTestInstance = config.services.matrix-synapse.isTestInstance;
  portOffset = if isTestInstance then 1 else 0;
  domainTestPrefix = if isTestInstance then "test." else "";
  domain = lib.fileContents "${private}/trueDomain.txt";
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
      # not required anymore
      # (import ./matrix-synapse-update.nix)
    ];

    # add both ports because firewall will not be applied in the container
    networking.firewall.allowedTCPPorts = [ 8008 8009 ];

    services.matrix-synapse = {
      enable = true;

      settings.allow_guest_access  = false;
      settings.enable_registration = false;
      settings.url_preview_enabled = true;

      dataDir = lib.mkIf (!isTestInstance) "/var/data/matrix-synapse";
      #settings.database_type = "sqlite3";
      settings.database_type = "psycopg2";

      settings.server_name = "${domainTestPrefix}${domain}";
      settings.public_baseurl = "https://${config.services.matrix-synapse.settings.server_name}/";
      localPort = 8008+portOffset;
      settings.listeners = [
        {
          bind_addresses = [ "::" "0.0.0.0" ];
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
        { bind_addresses = [ "127.0.0.1" ]; port = 9000+portOffset; type = "manhole"; resources = []; }
      ];
      settings.no_tls = true;


      #extraConfig = ''
      #  use_presence: true
      #  enable_group_creation: true
      #  group_creation_prefix: "unofficial/"
      #  acme:
      #    enabled: false
      #'';
      settings.use_presence = true;
      settings.enable_group_creation = true;
      settings.group_creation_prefix = "unofficial/";
      settings.acme.enabled = false;
      extraConfigFiles = [
        "/etc/nixos/secret/matrix-synapse/homeserver-secret.yaml"
        "/etc/nixos/secret/matrix-synapse/oidc-config.yaml"
      ];
      settings.app_service_config_files = [
        #"/etc/matrix-synapse/matrix_irc_hackint.yaml"
        (if isTestInstance
          then "/etc/nixos/secret/matrix-synapse/mautrix-telegram-test.yaml"
          else "/etc/nixos/secret/matrix-synapse/mautrix-telegram.yaml")
      ];
    };

    systemd.services.matrix-synapse.restartTriggers = with config.services.matrix-synapse; extraConfigFiles ++ settings.app_service_config_files;

    #NOTE This should keep it from being started but it doesn't.
    #systemd.services.matrix-synapse.wantedBy = lib.mkForce [];

    # Convert from sqlite to postgres:
    # 1. enable postgres in the config
    # 2. deploy it - ideally without trying to start the server
    # 3. get path of homeserver.yaml from `systemctl cat matrix-synapse`
    # 4. convert:
    #    su matrix-synapse -c 'synapse_port_db --sqlite-database /var/data/matrix-synapse/homeserver.db --postgres-config /nix/store/ilws5b4l7hxnj1fi17fp50rvggv71mk6-homeserver.yaml --curses'

    services.postgresql = {
      enable = true;
      enableTCPIP = false;
      initialScript = pkgs.writeText "synapse-init.sql" ''
        CREATE ROLE "matrix-synapse" WITH LOGIN PASSWORD NULL;
        CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
          TEMPLATE template0
          LC_COLLATE = "C"
          LC_CTYPE = "C"
          ENCODING = "UTF8";
      '';
    };

    fileSystems."/var/lib/postgresql" = {
      device = "/var/data/postgresql";
      options = [ "bind" ];
    };
  };
}
