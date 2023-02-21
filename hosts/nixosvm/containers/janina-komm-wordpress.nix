{ config, lib, pkgs, modules, private, ... }:
let
  privateForHost = "${private}/by-host/${config.networking.hostName}";

  ports = config.networking.firewall.allowedPorts;
  mysqlPort = 3308;
  name = "janina-komm";
  url1 = lib.fileContents "${privateForHost}/janina/url3.txt";
  url2 = lib.fileContents "${privateForHost}/janina/url4.txt";

  fetchTheme = { url, hash }: let
    nameParts = with builtins; match "(.*/)?([^.]+)[.]([0-9.]+)[.][a-z]+" url;
  in pkgs.stdenv.mkDerivation {
    name = builtins.elemAt nameParts 1;
    version = builtins.elemAt nameParts 2;
    src = pkgs.fetchzip { inherit url hash; };
    nativeBuildInputs = [ pkgs.pkgsBuildHost.unzip ];
    installPhase = ''mkdir -p $out; cp -R * $out/'';
  };
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
          #passwordFile = "/etc/nixos/secret/${name}-wordpress-db-password";  # not allowed because createLocally manages it
          createLocally = true;
        };
        extraConfig = ''
          if (strpos($_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false)
            $_SERVER['HTTPS']='on';
        '';
        themes = [
          (fetchTheme { url = "https://downloads.wordpress.org/theme/oceanwp.3.3.2.zip";       hash = "sha256-7ZjK+6p9C7QaRr/Hp6dECy4OjB0E8z/RK+rv2nVK80M="; })
          (fetchTheme { url = "https://downloads.wordpress.org/theme/neve.3.2.5.zip";          hash = "sha256-pMRwBN6B6eA3zmdhLnw2zSoGR6nKJikE+1axrzINQw8="; })
          (fetchTheme { url = "https://downloads.wordpress.org/theme/ashe.2.198.zip";          hash = "sha256-b/Tsf4wXff3HT9DNbWyujsWDZd/knePNdMIBnUwZhQ8="; })
          (fetchTheme { url = "https://downloads.wordpress.org/theme/twentyseventeen.3.0.zip"; hash = "sha256-QHEkvpc2CLjSopAIZRCelJnJvICQUYZfjTJYhTAbJuo="; })
        ];
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

      #services.mysql.port = mysqlPort;
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
