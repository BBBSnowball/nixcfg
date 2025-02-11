{ config, lib, pkgs, modules, privateForHost, secretForHost, ... }:
let
  ports = config.networking.firewall.allowedPorts;
  name = "janina-komm";
  containerName = "${name}-wordpress";
  inherit (privateForHost.janina) url3 url4 smtpHost;
  urls = [ url3 url4 ];
  mainUrl = lib.elemAt urls 0;
in {
  containers.${containerName} = {
    autoStart = true;
    config = { config, pkgs, ... }: let
      wp-cmd = pkgs.writeShellScriptBin "wp-${name}" ''
        exec sudo -u wordpress -- ${pkgs.wp-cli}/bin/wp -- --path=${config.services.httpd.virtualHosts.${name}.documentRoot} "$@"
      '';
    in {
      imports = [
        modules.container-common
        ./parts/wordpress-pkgs.nix
        ./parts/sendmail-to-smarthost.nix
      ];

      environment.systemPackages = with pkgs; [
        wp-cmd unzip
      ];

      services.wordpress.sites.${name} = {
        database = {
          socket = "/run/mysqld/mysqld.sock";
          name = "wordpress";
          createLocally = true;
        };
        extraConfig = ''
          if (strpos($_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false)
            $_SERVER['HTTPS']='on';
        '';
        themes = {
          inherit (pkgs.myWordpressThemes)
            oceanwp neve ashe twentyseventeen;
          #inherit (pkgs.wordpressPackages) twentyseventeen;
        };
        plugins = {
          inherit (pkgs.wordpressPackages.plugins)
            cookie-notice
            wp-gdpr-compliance
            wpforms-lite
            #wp-mail-smtp
            wp-change-email-sender;
        };
        virtualHost = {
          adminAddr = "postmaster@${mainUrl}";
          serverAliases = urls;
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

      services.mysql.settings.mysqld.skip-networking = true;

      programs.sendmail-to-smarthost = {
        enable = true;
        inherit smtpHost;
        sender = "noreply@${mainUrl}";
        passwordFile = "/run/credentials/system/smtp-password";
      };
    };

    bindMounts."/run/credentials/system".hostPath = "/run/credentials/container@${containerName}.service";
  };

  systemd.services."container@${containerName}".serviceConfig.LoadCredential = [ "smtp-password:${secretForHost}/smtp-password.txt" ];

  networking.firewall.allowedPorts."${name}-wordpress" = 8087;
}
