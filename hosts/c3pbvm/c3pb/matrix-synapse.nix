{ pkgs, config, lib, privateForHost, secretForHost, ... }:
let
  isTestInstance = config.services.matrix-synapse.isTestInstance;
  portOffset = if isTestInstance then 1 else 0;
  domainTestPrefix = if isTestInstance then "test." else "";
  domain = privateForHost.trueDomain;
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
      # This adds optional Python dependencies. This should happen automatically
      # based on `services.matrix-synapse.settings`, but our oidc config is added
      # from secretForHost, i.e. the NixOS module cannot see it.
      extras = [ "oidc" "postgres" ];

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
        "/\${CREDENTIALS_DIRECTORY}/homeserver-secret.yaml"
        "/\${CREDENTIALS_DIRECTORY}/oidc-config.yaml"
      ];
      settings.app_service_config_files = [
        #"/etc/matrix-synapse/matrix_irc_hackint.yaml"
        #(if isTestInstance
        #  then "${secretForHost}/matrix-synapse/mautrix-telegram-test.yaml"
        #  else "${secretForHost}/matrix-synapse/mautrix-telegram.yaml")
        "/var/data/matrix-synapse/mautrix-telegram.yaml"
      ];

      settings.max_upload_size = "100M";

      settings.log_config = ./matrix-synapse-log_config.yaml;
    };

    systemd.services.matrix-synapse.restartTriggers = with config.services.matrix-synapse; extraConfigFiles ++ settings.app_service_config_files;

    systemd.services.matrix-synapse.serviceConfig.LoadCredential = [
      "homeserver-secret.yaml:${secretForHost}/matrix-synapse/homeserver-secret.yaml"
      "oidc-config.yaml:${secretForHost}/matrix-synapse/oidc-config.yaml"
      (if isTestInstance
        then "mautrix-telegram.yaml:${secretForHost}/matrix-synapse/mautrix-telegram-test.yaml"
        else "mautrix-telegram.yaml:${secretForHost}/matrix-synapse/mautrix-telegram.yaml")
    ];
    systemd.services.matrix-synapse.serviceConfig.ExecStartPre = [
      "${pkgs.coreutils}/bin/ln -sfT \${CREDENTIALS_DIRECTORY}/mautrix-telegram.yaml /var/data/matrix-synapse/mautrix-telegram.yaml"
    ];

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
      # If the database starts empty after a Postgres update, synapse will re-init it and
      # generate a new key. This will cause lots of trouble so let's avoid that by not
      # creating the database by default, i.e. only enable this when starting the server
      # for the first time and thereafter disable it (before you upgrade stateVersion
      # the next time).
      initialScript = if true then null
        else pkgs.writeText "synapse-init.sql" ''
        CREATE ROLE "matrix-synapse" WITH LOGIN PASSWORD NULL;
        CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
          TEMPLATE template0
          LC_COLLATE = "C"
          LC_CTYPE = "C"
          ENCODING = "UTF8";
      '';

      package = pkgs.postgresql_15;
    };

    fileSystems."/var/lib/postgresql" = {
      device = "/var/data/postgresql";
      options = [ "bind" ];
    };

    # auto-upgrade database
    # see https://nixos.org/manual/nixos/stable/#module-services-postgres-upgrading
    systemd.services.postgresql =
    with builtins;
    let
      cfg = config.services.postgresql;
      inherit (cfg) package dataDir;
      inherit (package) psqlSchema;
      parentDir = dirOf dataDir;
      # dataDir default is "/var/lib/postgresql/${config.services.postgresql.package.psqlSchema}"
      check = lib.throwIf ((baseNameOf dataDir)!=psqlSchema) "Last path component of services.postgresql.dataDir must be the schema version.";
    in check {
      serviceConfig.TimeoutStartSec = "10min";
      preStart = lib.mkAfter ''
        if [ -e "${dataDir}/.upgrade_done" ] ; then
          echo "PostgreSQL database doesn't need any upgrade."
        elif [ -e "${parentDir}/current-data" -a -e "${parentDir}/current-pkg" ] && [ "$(readlink "${parentDir}/current-data")" != "${psqlSchema}" ] ; then
          echo "Upgrading PostgreSQL from $(readlink "${parentDir}/current-data") to ${psqlSchema}..."

          # initdb has already been done by NixOS' pre-start script
          ( cd "${parentDir}" && ${package}/bin/pg_upgrade \
            --old-datadir "$(readlink -f "${parentDir}/current-data")" --new-datadir "${dataDir}" \
            --old-bindir "${parentDir}/current-pkg/bin" --new-bindir "${package}/bin" )

          touch "${dataDir}/.upgrade_done"

          # don't run initialScript commands
          rm -f "${dataDir}/.first_startup"

          echo "Upgrade done."
        fi
      '';
      postStart = lib.mkAfter ''
        ln -sfT "${psqlSchema}" "${parentDir}/current-data"
        if [ ! -e "${parentDir}/current-pkg" ] || [ "$(realpath "${parentDir}/current-pkg")" != "${package}" ] ; then
          ${pkgs.nix}/bin/nix-store --add-root "${parentDir}/current-pkg" -r "${package}"
        fi
      '';
    };
  };
}
