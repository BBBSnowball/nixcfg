{ config, lib, pkgs, modules, privateForHost, secretForHost, ... }:
let
  ports = config.networking.firewall.allowedPorts;
  mysqlPort = 3307;
  url1 = lib.fileContents "${privateForHost}/janina/url1.txt";
  url2 = lib.fileContents "${privateForHost}/janina/url2.txt";

  passwordProtectPlugin = pkgs.fetchzip {
    url = "https://downloads.wordpress.org/plugin/password-protected.2.7.4.zip";
    sha256 = "sha256-6kU4duN3V/z0jIiShxzCHTG2GIZPKRook0MIQVXWLQg=";
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

      services.wordpress.sites."janina" = {
        database = {
          #host = "127.0.0.1";
          #port = mysqlPort;
          socket = "/run/mysqld/mysqld.sock";
          name = "wordpress";
          #passwordFile = "${secretForHost}/janina-wordpress-db-password";  # not allowed because createLocally manages it
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

      #services.mysql.port = 3307;
      services.mysql.settings.mysqld.skip-networking = true;

      programs.msmtp = {
        enable = true;
        accounts.default = {
          auth = true;
          host = "192.168.84.130";
          port = "587";
          passwordeval = "cat ${secretForHost}/smtp-password.txt";
          user = "noreply@${url1}";
          from = "noreply@${url1}";
          tls = "on";
          tls_certcheck = "off";
        };
      };

      systemd.services.phpfpm-wordpress-janina.preStart = ''
        chmod 440 ${secretForHost}/{smtp-password.txt,janina-wordpress-db-password}
        chown wordpress:root ${secretForHost}/janina-wordpress-db-password
        chown root:wwwrun ${secretForHost}/smtp-password.txt
        chmod 711 ${secretForHost}
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
    #mkdir -p -m 0711 "$root${secretForHost}"
    #cp -u --remove-destination ${secretForHost}/{smtp-password.txt,janina-wordpress-db-password} -t $root${secretForHost}/

    chmod 600 ${secretForHost}/{smtp-password.txt,janina-wordpress-db-password}
    systemd-nspawn -D "$root" --bind-ro=/nix/store:/nix/store --pipe -- `which mkdir` -p -m 0755 "/etc/nixos"
    systemd-nspawn -D "$root" --bind-ro=/nix/store:/nix/store --pipe -- `which mkdir` -p -m 0711 "${secretForHost}"
    tar -C ${secretForHost} -c smtp-password.txt janina-wordpress-db-password \
      | systemd-nspawn -D "$root" --bind-ro=/nix/store:/nix/store --pipe -- `which tar` -C ${secretForHost} -x
  '';
}
