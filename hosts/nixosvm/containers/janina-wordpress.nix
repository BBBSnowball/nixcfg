{ config, lib, pkgs, modules, privateForHost, secretForHost, ... }:
let
  ports = config.networking.firewall.allowedPorts;
  name = "janina";
  containerName = "${name}-wordpress";
  inherit (privateForHost.janina) url1 url2 smtpHost;
  urls = [ url2 url1 ];
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
        #themes = { inherit responsiveTheme; };
        plugins = {
          inherit (pkgs.myWordpressPlugins) passwordProtectPlugin;
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
  
  networking.firewall.allowedPorts."${name}-wordpress" = 8086;
}
