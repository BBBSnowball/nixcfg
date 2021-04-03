{ config, lib, pkgs, modules, private, ... }:
let
  ports = config.networking.firewall.allowedPorts;
  mysqlPort = 3307;
  url1 = (lib.fileContents "${private}/janina/url1.txt") + "\n";
  url2 = (lib.fileContents "${private}/janina/url2.txt") + "\n";

  passwordProtectPlugin = pkgs.fetchzip {
    url = "https://downloads.wordpress.org/plugin/password-protected.2.4.zip";
    sha256 = "sha256-whZfEyoTKj3ttEjh2zzpMnnPzCVHQlqfsih7QRa8wTU=";
  };
in {
  containers.janina-wordpress = {
    autoStart = true;
    config = { config, pkgs, ... }: let
      wp-cmd = pkgs.writeShellScriptBin "wp-janina" ''
        exec sudo -u wordpress -- ${pkgs.wp-cli}/bin/wp -- --path=${config.services.httpd.virtualHosts.janina.documentRoot} "$@"
      '';
    in {
      imports = [ modules.container-common ];

      environment.systemPackages = with pkgs; [
        wp-cmd unzip
      ];

      services.wordpress."janina" = {
        database = {
          #host = "127.0.0.1";
          #port = mysqlPort;
          socket = "/run/mysqld/mysqld.sock";
          name = "wordpress";
          passwordFile = "/etc/nixos/secret/janina-wordpress-db-password";
          createLocally = true;
        };
        extraConfig = ''
          if (strpos($_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false)
            $_SERVER['HTTPS']='on';
        '';
        #themes = [ responsiveTheme ];
        plugins = [ passwordProtectPlugin ];
        virtualHost = {
          adminAddr = "postmaster@${url2}";
          serverAliases = [ url2 ];
          listen = [ { port = ports.janina-wordpress.port; } ];
          locations."/extra-fonts" = {
            #alias = "/var/www/extra-fonts";
            alias = "/var/www%{REQUEST_URI}";  # oh, well... ugly hack!
            extraConfig = ''
              Require all granted
            '';
          };
        };
      };

      services.mysql.port = 3307;
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

      systemd.services.phpfpm-wordpress-janina.preStart = ''
        chmod 440 /etc/nixos/secret/{smtp-password.txt,janina-wordpress-db-password}
        chown wordpress:root /etc/nixos/secret/janina-wordpress-db-password
        chown root:wwwrun /etc/nixos/secret/smtp-password.txt
        chmod 711 /etc/nixos/secret
      '';
      systemd.services.phpfpm-wordpress-janina.serviceConfig.PermissionsStartOnly = true;
    };
  };

  networking.firewall.allowedPorts.janina-wordpress  = 8086;

  systemd.services."container@janina-wordpress".path = with pkgs; [ gnutar which ];
  systemd.services."container@janina-wordpress".preStart = ''
    #FIXME If the container makes these into symlinks, we may overwrite files on the host.
    # -> pipe tar into nspawn instead..?
    #mkdir -p -m 0755 "$root/etc/nixos"
    #mkdir -p -m 0711 "$root/etc/nixos/secret"
    #cp -u --remove-destination /etc/nixos/secret/{smtp-password.txt,janina-wordpress-db-password} -t $root/etc/nixos/secret/

    chmod 600 /etc/nixos/secret/{smtp-password.txt,janina-wordpress-db-password}
    systemd-nspawn -D "$root" --bind-ro=/nix/store:/nix/store --pipe -- `which mkdir` -p -m 0755 "/etc/nixos"
    systemd-nspawn -D "$root" --bind-ro=/nix/store:/nix/store --pipe -- `which mkdir` -p -m 0711 "/etc/nixos/secret"
    tar -C /etc/nixos/secret -c smtp-password.txt janina-wordpress-db-password \
      | systemd-nspawn -D "$root" --bind-ro=/nix/store:/nix/store --pipe -- `which tar` -C /etc/nixos/secret -x
  '';
}
