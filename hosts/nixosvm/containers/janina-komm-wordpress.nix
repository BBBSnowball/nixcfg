{ config, lib, pkgs, modules, privateForHost, secretForHost, ... }:
let
  ports = config.networking.firewall.allowedPorts;
  port = 8087;
  mysqlPort = 3308;
  name = "janina-komm";
  inherit (privateForHost.janina) url3 url4 smtpHost;
  url1 = url3;
  url2 = url4;

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
          createLocally = true;
        };
        extraConfig = ''
          if (strpos($_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false)
            $_SERVER['HTTPS']='on';
        '';
        themes = {
          oceanwp         = fetchTheme { url = "https://downloads.wordpress.org/theme/oceanwp.4.0.2.zip";       hash = "sha256-cNcdLYWcAz9/Wqr2dTa8m97VCq7i/IoX17Fu6ZTzmjs="; };
          #neve            = fetchTheme { url = "https://downloads.wordpress.org/theme/neve.3.2.5.zip";          hash = "sha256-pMRwBN6B6eA3zmdhLnw2zSoGR6nKJikE+1axrzINQw8="; };
          neve            = fetchTheme { url = "https://downloads.wordpress.org/theme/neve.3.8.13.zip";         hash = "sha256-hJ0noKHIZ+SXSIy0z3ixCJNqcc/nFIXezqJ+sz7qzlc="; };
          ashe            = fetchTheme { url = "https://downloads.wordpress.org/theme/ashe.2.246.zip";          hash = "sha256-87yWJhuXSfpp6L30/P9kN8jcqYVFLKlXU0NXCppUGrA="; };
          twentyseventeen = fetchTheme { url = "https://downloads.wordpress.org/theme/twentyseventeen.3.8.zip"; hash = "sha256-4GOzQtvre7ifYe7oQPFPcD+WRmZZ9G5OZcuRFZ92fw4="; };
          #inherit (pkgs.wordpressPackages) twentyseventeen;
        };
        plugins = {
          inherit (pkgs.wordpressPackages.plugins)
            cookie-notice
            wp-gdpr-compliance
            wpforms-lite;
        };
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
      chmod 600 ${secretForHost}/smtp-password.txt
      systemd-nspawn -D "$root" --bind-ro=/nix/store:/nix/store --pipe -- `which mkdir` -p -m 0755 "/etc/nixos"
      systemd-nspawn -D "$root" --bind-ro=/nix/store:/nix/store --pipe -- `which mkdir` -p -m 0711 "${secretForHost}"
      tar -C ${secretForHost} -c smtp-password.txt \
        | systemd-nspawn -D "$root" --bind-ro=/nix/store:/nix/store --pipe -- `which tar` -C ${secretForHost} -x
    '';
  };
}
