{ config, lib, modules, privateForHost, ... }:
let
  ports = config.networking.firewall.allowedPorts;
in {
  containers.mate = {
    autoStart = true;
    config = { config, pkgs, ... }: let
      #node = pkgs.nodejs-8_x;
      node = pkgs.nodejs;
    in {
      imports = [ modules.container-common ];

      environment.systemPackages = with pkgs; [
        node cacert
        #NOTE npm2nix doesn't seem to exist in 19.09 but I didn't get this to work anyway.
        #     Do an `npm update` in ~strichliste/strichliste after an update.
	sqlite-interactive
      ];

      users.users.strichliste = {
        isNormalUser = true;
        extraGroups = [ ];
        openssh.authorizedKeys = config.users.users.root.openssh.authorizedKeys;
      };

      systemd.services.strichliste = {
        description = "Strichliste API";
        serviceConfig = {
          User = "strichliste";
          Group = "users";
          ExecStart = "${node}/bin/node server.js";
          WorkingDirectory = "/home/strichliste/strichliste";
          KillMode = "process";
        };
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" "fs.target" ];
      };

      systemd.services.pizzaimap = {
        description = "Retrieve emails with orders and make them available for the web client";
        serviceConfig = {
          User = "strichliste";
          Group = "users";
          ExecStart = "${node}/bin/node --harmony pizzaimap.js";
          WorkingDirectory = "/home/strichliste/pizzaimap";
          KillMode = "process";
          # must define PIZZA_PASSWORD
          EnvironmentFile = "/root/pizzaimap.vars";

          RestartSec = "10";
          Restart = "always";
        };
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" "fs.target" ];
      };

      services.httpd = {
        enable = true;
        adminAddr = "postmaster@${lib.fileContents "${privateForHost}/w-domain.txt"}";
      };
      services.httpd.virtualHosts.default = {
        documentRoot = "/var/www/html";
        listen = [{ port = ports.strichliste-apache.port; ssl = false; }];
        extraConfig = ''
          #RewriteEngine on

          ProxyPass        /strich-api  http://localhost:${toString ports.strichliste-node.port}
          ProxyPassReverse /strich-api  http://localhost:${toString ports.strichliste-node.port}

          ProxyPass        /recent-orders.txt  http://localhost:${toString ports.pizzaimap.port}/recent-orders.txt
          ProxyPassReverse /recent-orders.txt  http://localhost:${toString ports.pizzaimap.port}/recent-orders.txt

          # set cache control so the Android tablet that has replaced hackpad won't cache it forever
          # (but not for the images because there are many of them and we can change the filename if necessary)
          <FilesMatch ".(js|css|html)$">
            Header set Cache-Control "max-age=600, must-revalidate"
          </FilesMatch>
        '';
      };
    };
  };

  networking.firewall.allowedPorts.strichliste-apache = 8081;
  networking.firewall.allowedPorts.strichliste-node   = 8080;  # fixed in server config
  networking.firewall.allowedPorts.pizzaimap          = 1237;  # fixed in source
}
