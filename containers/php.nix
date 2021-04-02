{ config, lib, modules, private, ... }:
let
  ports = config.networking.firewall.allowedPorts;
  url1 = builtins.readFile "${private}/janina/url1.txt";
in {
  containers.php = {
    autoStart = true;
    config = { config, pkgs, ... }: let
      poolName = "php";
      phpfpmSocketName = config.services.phpfpm.pools.php.socket;
    in {
      imports = [ modules.container-common ];

      environment.systemPackages = with pkgs; [
        php74Packages.composer
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
    };
  };

  networking.firewall.allowedPorts.phpserver  = 8085;
}
