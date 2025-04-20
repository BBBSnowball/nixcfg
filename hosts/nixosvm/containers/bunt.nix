{ config, lib, modules, pkgs, secretForHost, ... }:
let
  inherit (pkgs) system;
  ports = config.networking.firewall.allowedPorts;
  name = "bunt";
  containerName = name;
  hostNameMain = "bunt";
  hostNameNC = "buntc";
  hostNameWP = "buntw";

  sslKeys = let
    creds = "/run/credentials/nginx.service";
    #creds = "/run/credstore";
  in {
    onlySSL = true;
    sslCertificate = "${creds}/secret_clown-origin-cert.pem";
    sslCertificateKey = "${creds}/secret_clown-private-key.pem";
  };
in {
  containers.${name} = {
    autoStart = true;
    config = { config, pkgs, ... }: let
      wp-cmd = pkgs.writeShellScriptBin "wp-${name}" ''
        exec sudo -u wordpress -- ${pkgs.wp-cli}/bin/wp --path=${config.services.nginx.virtualHosts.${hostNameWP}.root} "$@"
      '';
    in {
      imports = [
        modules.container-common
        ./parts/wordpress-pkgs.nix
      ];

      environment.systemPackages = with pkgs; [
        wp-cmd unzip
      ];

      services.nextcloud = {
        enable = true;
        autoUpdateApps.enable = true;
        config.adminpassFile = "/run/credentials/nextcloud-setup.service/secret_nextcloud-admin-password";
        #secretFile = "/run/credentials/phpfpm-nextcloud.service/secret_nextcloud-config";
        # -> Name must be the same regardless of which service is using it.
        secretFile = "/run/nextcloud/secret.conf";
        # -> Can we cheat? -> Yes, but phpfpm drop privileges, so we have to change ownership.
        #secretFile = "\".getenv('CREDENTIALS_DIRECTORY').\"/secret_nextcloud-config";
      
        # We have to manually specify the version, so we can ensure that migrations run between major upgrades.
        package = pkgs.nextcloud30;

        hostName = hostNameNC;
        #https = true;
        #config.overwriteProtocol = "https";

        # not needed and should be more secure without it
        enableImagemagick = false;
      
        config.dbhost = "/run/postgresql";
        config.dbtype = "pgsql";
      };

      services.wordpress.webserver = "nginx";

      services.wordpress.sites.${hostNameWP} = {
        database = {
          socket = "/run/mysqld/mysqld.sock";
          name = "wordpress";
          createLocally = true;
        };

        virtualHost = {
          adminAddr = "postmaster@localhost";
          serverAliases = [ hostNameWP ];
          listen = [ { port = ports."${name}-wp".port; } ];
          locations."/extra-fonts" = {
            #alias = "/var/www/extra-fonts";
            alias = "/var/www%{REQUEST_URI}";  # oh, well... ugly hack!
            extraConfig = ''
              Require all granted
            '';
          };
        };

        plugins = {
          inherit (pkgs.myWordpressPlugins)
            the-events-calendar
            caldavlist;
        };
      };

      services.postgresql = {
        enable = true;

        enableTCPIP = false; # still keeps localhost
        settings.listen_addresses = lib.mkForce "";

        ensureDatabases = [ "nextcloud" ];
        ensureUsers = [
          {
            name = "nextcloud";
            ensureDBOwnership = true;
          }
        ];
      };
      services.postgresqlBackup.enable = true;
      #services.postgresqlBackup.location = ...;  # default is "/var/backup/postgresql", which is fine

      services.nginx.virtualHosts.${hostNameNC} = {
        listen = [
          #{ addr = "0.0.0.0"; port = ports.bunt-nc.port; ssl = true; }
          { addr = "[::]";    port = ports.bunt-nc.port; ssl = true; }
        ];
      } // sslKeys;

      services.nginx.virtualHosts.${hostNameWP} = {
        listen = [
          #{ addr = "0.0.0.0"; port = ports.bunt-wp.port; ssl = true; }
          { addr = "[::]";    port = ports.bunt-wp.port; ssl = true; }
        ];
      } // sslKeys;

      services.nginx.virtualHosts.${hostNameMain} = {
        root = "/var/www/html";
        listen = [
          #{ addr = "0.0.0.0"; port = ports.bunt-mn.port; ssl = true; }
          { addr = "[::]";    port = ports.bunt-mn.port; ssl = true; }
        ];
      } // sslKeys;

      # redirect HTTP to HTTPS, similar to forceSSL but custom port
      services.nginx.virtualHosts.http = {
        listen = [
          #{ addr = "0.0.0.0"; port = ports.bunt-http.port; }
          { addr = "[::]";    port = ports.bunt-http.port; }
        ];

        locations."/" = {
          extraConfig = ''
            return 301 https://$host$request_uri;
          '';
        };
      };

      systemd.services."nginx" = {
        serviceConfig.LoadCredential = [ "secret_clown-private-key.pem" "secret_clown-origin-cert.pem" ];
      };

      systemd.services."nextcloud-setup" = {
        serviceConfig.LoadCredential = [ "secret_nextcloud-admin-password" "secret_nextcloud-config" ];
        after = [ "postgresql.service" ];
        serviceConfig.ExecStartPre = [
          #"${pkgs.coreutils}/bin/install -d -m 0400 -o nextcloud /run/nextcloud"
          "+${pkgs.coreutils}/bin/install -D -m 0400 -o nextcloud %d/secret_nextcloud-config /run/nextcloud/secret.conf"
        ];
      };

      systemd.services."phpfpm-nextcloud" = {
        serviceConfig.LoadCredential = [ "secret_nextcloud-config" ];
        serviceConfig.ExecStartPre = [
          #"${pkgs.coreutils}/bin/install -d -m 0400 -o nextcloud /run/nextcloud"
          "${pkgs.coreutils}/bin/install -D -m 0400 -o nextcloud %d/secret_nextcloud-config /run/nextcloud/secret.conf"
        ];
      };
      #services.phpfpm.pools.nextcloud.phpEnv.CREDENTIALS_DIRECTORY = "/run/credentials/phpfpm-nextcloud.service";
    };

    # This doesn't support directories, it seems.
    #extraFlags = [ "--load-credential=secret:${secretForHost}/${name}/" ];
    # Bind-mount the credentials to one of the paths where systemd will look by default.
    bindMounts."/run/credstore".hostPath = "/run/credentials/container@${containerName}.service";
  };

  systemd.services."container@${containerName}".serviceConfig.LoadCredential = [ "secret:${secretForHost}/${name}/" ];

  networking.firewall.allowedPorts.bunt-nc = 8091;
  networking.firewall.allowedPorts.bunt-wp = 8092;
  networking.firewall.allowedPorts.bunt-mn = 8093;
  networking.firewall.allowedPorts.bunt-http = 8094;
}
