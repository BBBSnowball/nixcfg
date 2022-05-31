{ config, lib, pkgs, modules, private, ... }:
let
  ports = config.networking.firewall.allowedPorts;
  mysqlPort = 3308;
  name = "janina-komm";
  url1 = lib.fileContents "${private}/janina/url3.txt";
  url2 = lib.fileContents "${private}/janina/url4.txt";
in {
  containers.janina-komm-wordpress = {
    autoStart = true;
    config = { config, pkgs, ... }: let
      wp-cmd = pkgs.writeShellScriptBin "wp-${name}" ''
        exec sudo -u wordpress -- ${pkgs.wp-cli}/bin/wp -- --path=${config.services.httpd.virtualHosts.${name}.documentRoot} "$@"
      '';
    in {
      imports = [ modules.container-common ];

      environment.systemPackages = with pkgs; [
        wp-cmd unzip
      ];

      services.wordpress.sites.${name} = {
        database = {
          #host = "127.0.0.1";
          #port = mysqlPort;
          socket = "/run/mysqld/mysqld.sock";
          name = "wordpress";
          passwordFile = "/etc/nixos/secret/${name}-wordpress-db-password";
          createLocally = true;
        };
        extraConfig = ''
          if (strpos($_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false)
            $_SERVER['HTTPS']='on';
        '';
        #themes = [ responsiveTheme ];
        plugins = [ ];
        virtualHost = {
          adminAddr = "postmaster@${url1}";
          serverAliases = [ url2 ];
          listen = [ { port = ports."${name}-wordpress".port; } ];
          locations."/extra-fonts" = {
            #alias = "/var/www/extra-fonts";
            alias = "/var/www%{REQUEST_URI}";  # oh, well... ugly hack!
            extraConfig = ''
              Require all granted
            '';
          };
        };
      };

      services.mysql.port = mysqlPort;
      services.mysql.settings.mysqld.skip-networking = true;

      programs.msmtp = {
        enable = true;
        accounts.default = {
          auth = true;
          host = "192.168.84.130";
          port = "587";
          passwordeval = "cat /etc/nixos/secret/smtp-password.txt";
          user = "noreply@${url1}";
          from = "noreply@${url1}";
          tls = "on";
          tls_certcheck = "off";
        };
      };

      systemd.services."phpfpm-wordpress-${name}" = {
        preStart = ''
          chmod 440 /etc/nixos/secret/{smtp-password.txt,${name}-wordpress-db-password}
          chown wordpress:root /etc/nixos/secret/${name}-wordpress-db-password
          chown root:wwwrun /etc/nixos/secret/smtp-password.txt
          chmod 711 /etc/nixos/secret
        '';
        serviceConfig.PermissionsStartOnly = true;
      };
    };
  };

  networking.firewall.allowedPorts."${name}-wordpress" = 8087;

  systemd.services."container@${name}-wordpress" = {
    path = with pkgs; [ gnutar which ];
    preStart = ''
      chmod 600 /etc/nixos/secret/{smtp-password.txt,${name}-wordpress-db-password}
      systemd-nspawn -D "$root" --bind-ro=/nix/store:/nix/store --pipe -- `which mkdir` -p -m 0755 "/etc/nixos"
      systemd-nspawn -D "$root" --bind-ro=/nix/store:/nix/store --pipe -- `which mkdir` -p -m 0711 "/etc/nixos/secret"
      tar -C /etc/nixos/secret -c smtp-password.txt ${name}-wordpress-db-password \
        | systemd-nspawn -D "$root" --bind-ro=/nix/store:/nix/store --pipe -- `which tar` -C /etc/nixos/secret -x
    '';
  };
}
