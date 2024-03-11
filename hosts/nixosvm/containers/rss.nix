{ config, lib, modules, nixpkgs-rss, ... }:
let
  ports = config.networking.firewall.allowedPorts;
in {
  containers.rss = {
    autoStart = true;
    #nixpkgs = nixpkgs-rss;
    config = { config, pkgs, ... }: let
      poolName = "my_selfoss_pool";
      phpfpmSocketName = config.services.phpfpm.pools.my_selfoss_pool.socket;
    in {
      imports = [ modules.container-common ];

      environment.systemPackages = with pkgs; [
      ];

      services.nginx = {
        enable = true;
        virtualHosts.rss = {
          listen = [ { addr = "0.0.0.0"; port = ports.rss.port; extraParameters = [ "default_server" ]; } ];
          root = "/var/www/html";

          locations."/favicon.ico" = {
            root = "/var/lib/selfoss/public";
          };
          locations."/selfoss" = {
            root = "/var/lib/selfoss";
            extraConfig = ''
              # similar to nixos/modules/services/mail/roundcube.nix - well, not so similar anymore
              location ~ ^/selfoss/php/(.*)$ {
                alias /var/lib/selfoss/index.php?$1;
                fastcgi_pass unix:/run/phpfpm/my_selfoss_pool.sock;
            
                # We could include ${pkgs.nginx}/conf/fastcgi_params but we need a different
                # SCRIPT_FILENAME, SCRIPT_NAME and REQUEST_URI.

                fastcgi_param SCRIPT_FILENAME /var/lib/selfoss/index.php;                                                                                     
                fastcgi_param SCRIPT_NAME /selfoss/index.php;
                fastcgi_param REQUEST_URI        /selfoss/$1;

                fastcgi_param  QUERY_STRING       $query_string;
                fastcgi_param  REQUEST_METHOD     $request_method;
                fastcgi_param  CONTENT_TYPE       $content_type;
                fastcgi_param  CONTENT_LENGTH     $content_length;

                #fastcgi_param  REQUEST_URI        $request_uri;
                fastcgi_param  DOCUMENT_URI       $document_uri;
                fastcgi_param  DOCUMENT_ROOT      $document_root;
                fastcgi_param  SERVER_PROTOCOL    $server_protocol;
                fastcgi_param  REQUEST_SCHEME     $scheme;
                fastcgi_param  HTTPS              $https if_not_empty;

                fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
                fastcgi_param  SERVER_SOFTWARE    nginx/$nginx_version;                                                                                       

                fastcgi_param  REMOTE_ADDR        $remote_addr;
                fastcgi_param  REMOTE_PORT        $remote_port;
                fastcgi_param  SERVER_ADDR        $server_addr;
                fastcgi_param  SERVER_PORT        $server_port;
                fastcgi_param  SERVER_NAME        $server_name;

                # PHP only, required if PHP was built with --enable-force-cgi-redirect
                fastcgi_param  REDIRECT_STATUS    200;
              }

              # see https://github.com/SSilence/selfoss/wiki/nginx-configuration

              # regex matches win so make this a regex match
              location ~ ^/selfoss/favicons/(.*)$   { alias /var/lib/selfoss/data/favicons/$1; }                                                                     
              location ~ ^/selfoss/thumbnails/(.*)$ { alias /var/lib/selfoss/data/thumbnails/$1; }                                                                   

              location ~ ^/selfoss/public/(.*)$     { alias /var/lib/selfoss/public/$1; }

              location ~ ^/selfoss/(.*)$ {
                try_files /public/$1 /selfoss/php/$1$is_args$args;
              }
            '';
          };
        };
      };

      services.selfoss = {
        enable = true;
        database.type = "sqlite";
        extraConfig = ''
          salt=22lkjl1289asdf099s8f
          items_perpage=50
          rss_max_items=3000
          homepage=unread
          base_url=/selfoss/
          ; hide share buttons
          share=
          items_lifetime=100
          ; quick 'n' dirty fix for only marking some items read:
          items_perpage=20
          auto_stream_more=0
          ; php-fpm has catch_workers_output=1 and it logs to syslog
          logger_destination=file:php://stderr
        '';
        pool = "${poolName}";
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
      };

      system.activationScripts.wwwroot = lib.stringAfter ["users" "groups"] ''
        # create www root
        mkdir -m 0750 -p /var/www/html
        chown root:nginx /var/www/html
        if [ ! -e /var/www/html/index.html ] ; then
          echo "nothing to see here" >/var/www/html/index.html
        fi

        #NOTE This does *not* work because selfoss-config makes it world-readable again :-(
        # world-readable data directory is not a good idea!
        chmod o-rwx /var/lib/selfoss/data
        # in fact, no reason for selfoss to be world-readable, as well
        chmod o-rwx /var/lib/selfoss
        #echo "BLUB: $SYSTEM_CONFIG, $systemConfig"
        #ls -ld /var/lib/selfoss
      '';
    };
  };

  networking.firewall.allowedPorts.rss  = 8084;
}
