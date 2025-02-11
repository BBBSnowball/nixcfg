{ config, lib, modules, privateForHost, secretForHost, ... }:
let
  ports = config.networking.firewall.allowedPorts;
  inherit (privateForHost.janina) url1 smtpHost;
  containerName = "php";
in {
  containers.${containerName} = {
    autoStart = true;
    config = { config, pkgs, ... }: let
      poolName = "php";
      phpfpmSocketName = config.services.phpfpm.pools.php.socket;
    in {
      imports = [
        modules.container-common
        ./parts/sendmail-to-smarthost.nix
      ];

      environment.systemPackages = with pkgs; [
        phpPackages.composer
      ];

      services.nginx = {
        enable = true;
        virtualHosts.php = {
          listen = [ { addr = "0.0.0.0"; port = ports.phpserver.port; extraParameters = [ "default_server" ]; } ];
          root = "/var/www/html";

          locations."~ \\.php$" = {
            extraConfig = ''
              fastcgi_split_path_info ^(.+\.php)(/.+)$;
              fastcgi_pass unix:${config.services.phpfpm.pools.${poolName}.socket};
              include ${pkgs.nginx}/conf/fastcgi_params;
              include ${pkgs.nginx}/conf/fastcgi.conf;
            '';
          };
        };
      };

      # custom pool because the default one has an excess of workers 
      services.phpfpm.pools."${poolName}" = {
        user = "nginx";
        settings.pm = "dynamic";
        settings."pm.max_children" = 30;
        settings."pm.start_servers" = 5;
        settings."pm.min_spare_servers" = 2;
        settings."pm.max_spare_servers" = 5;
        settings."pm.max_requests" = 500;
        settings."listen.owner" = "nginx";
        settings."listen.group" = "nginx";
        settings."listen.mode" = "0600";
        settings."catch_workers_output" = 1;
        #phpOptions = ''
        #  sendmail_path = "/run/wrappers/bin/sendmail"
        #'';
      };

      services.mysql.enable = true;
      services.mysql.package = pkgs.mariadb;
      services.mysql.settings.mysqld.skip-networking = true;

      programs.sendmail-to-smarthost = {
        enable = true;
        inherit smtpHost;
        sender = "noreply@${url1}";
        passwordFile = "/run/credentials/system/smtp-password";
      };
    };

    bindMounts."/run/credentials/system".hostPath = "/run/credentials/container@${containerName}.service";
  };

  systemd.services."container@${containerName}".serviceConfig.LoadCredential = [ "smtp-password:${secretForHost}/smtp-password.txt" ];

  networking.firewall.allowedPorts.phpserver = 8085;
}
