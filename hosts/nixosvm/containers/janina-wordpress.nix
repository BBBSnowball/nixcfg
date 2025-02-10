{ config, lib, pkgs, modules, privateForHost, secretForHost, ... }:
let
  ports = config.networking.firewall.allowedPorts;
  port = 8086;
  mysqlPort = 3307;
  name = "janina";
  inherit (privateForHost.janina) url1 url2 smtpHost;

  passwordProtectPlugin = pkgs.fetchzip {
    url = "https://downloads.wordpress.org/plugin/password-protected.2.7.4.zip";
    sha256 = "sha256-6kU4duN3V/z0jIiShxzCHTG2GIZPKRook0MIQVXWLQg=";
  };
in {
  containers."${name}-wordpress" = {
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
          #passwordFile = "${secretForHost}/${name}-wordpress-db-password";  # not allowed because createLocally manages it
          createLocally = true;
        };
        extraConfig = ''
          if (strpos($_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false)
            $_SERVER['HTTPS']='on';
        '';
        #themes = { inherit responsiveTheme; };
        plugins = {
          inherit passwordProtectPlugin;
        };
        virtualHost = {
          adminAddr = "postmaster@${url2}";
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

      #services.mysql.port = mysqlPort;
      services.mysql.settings.mysqld.skip-networking = true;

      programs.msmtp = {
        enable = true;
        accounts.default = {
          auth = true;
          host = smtpHost;
          port = "587";
          passwordeval = "cat ${secretForHost}/smtp-password.txt";
          user = "noreply@${url1}";
          from = "noreply@${url1}";
          tls = "on";
        };
      };

      systemd.services."phpfpm-wordpress-${name}" = {
        preStart = ''
          chmod 440 ${secretForHost}/{smtp-password.txt,${name}-wordpress-db-password}
          chown wordpress:root ${secretForHost}/${name}-wordpress-db-password
          chown root:wwwrun ${secretForHost}/smtp-password.txt
          chmod 711 ${secretForHost}
        '';
        serviceConfig.PermissionsStartOnly = true;
      };
    };
  };

  networking.firewall.allowedPorts."${name}-wordpress" = port;

  systemd.services."container@${name}-wordpress" = {
    path = with pkgs; [ gnutar which ];
    preStart = ''
      chmod 600 ${secretForHost}/{smtp-password.txt,${name}-wordpress-db-password}
      systemd-nspawn -D "$root" --bind-ro=/nix/store:/nix/store --pipe -- `which mkdir` -p -m 0755 "/etc/nixos"
      systemd-nspawn -D "$root" --bind-ro=/nix/store:/nix/store --pipe -- `which mkdir` -p -m 0711 "${secretForHost}"
      tar -C ${secretForHost} -c smtp-password.txt ${name}-wordpress-db-password \
        | systemd-nspawn -D "$root" --bind-ro=/nix/store:/nix/store --pipe -- `which tar` -C ${secretForHost} -x
    '';
  };
}
