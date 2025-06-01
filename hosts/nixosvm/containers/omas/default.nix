{ config, lib, modules, pkgs, privateForHost, secretForHost, ... }:
let
  inherit (privateForHost.sonline0) trueDomain;
  inherit (privateForHost.omas) domain;
  #ports = config.networking.firewall.allowedPorts;
  name = "omas";
  containerName = name;
  hostName = domain;
  oldDomain = "ogr.${trueDomain}";

  ports = let x = port: { inherit port; type = "tcp"; }; in {
    omas-wordpress = x 8100;
    omas-intern = x 8100;
    omas-nextcloud = x 8100;
    omas-discourse = x 8100;
    omas-wiki = x 8100;
    omas-accounts = x 8100;
  };
  portsForFirewall = {
    inherit (ports) omas-wordpress;
  };
in {
  containers.${name} = {
    autoStart = true;
    config = { config, pkgs, ... }: let
    in {
      imports = [
        modules.container-common
        ./discourse.nix
        #./kanidm.nix
        ./lldap.nix
        ./mediawiki.nix
        ./nginx-ldap.nix
        ./nextcloud.nix
        ./postgresql.nix
        ./send-mail.nix
        ./wordpress.nix
      ];
      
      _module.args = {
        inherit ports domain;
        inherit (privateForHost.omas) smtpHost reverse_proxy_ip;
      };

      services.nginx.commonHttpConfig = ''
        map $host $hostSuffix {
          "~^(intern[.])(.+)$" $2;
          default $host;
        }
      '';

      services.nginx.virtualHosts.${hostName} = {
        locations."= /favicon.ico".alias = "/var/www/html-intern/favicon-public.ico";
      };

      services.nginx.virtualHosts."intern.${hostName}" = {
        root = "/var/www/html-intern";
        listen = [
          { addr = "0.0.0.0"; port = ports.omas-intern.port; }
        ];

        locations."/".extraConfig = ''
          sub_filter_once off;
          sub_filter '{domain}' $hostSuffix;
        '';
      };

      # remove read permissions for the group because PHP workers share the group
      #systemd.tmpfiles.rules = [
      #  "d /var/log/nginx 0700 nginx root -"
      #];
      systemd.services.nginx.serviceConfig.LogsDirectoryMode = lib.mkForce "0700";
    };

    # This doesn't support directories, it seems.
    #extraFlags = [ "--load-credential=secret:${secretForHost}/${name}/" ];
    # Bind-mount the credentials to one of the paths where systemd will look by default.
    bindMounts."/run/credstore".hostPath = "/run/credentials/container@${containerName}.service";
  };

  systemd.services."container@${containerName}".serviceConfig.LoadCredential = [ "secret:${secretForHost}/${name}/" ];

  networking.firewall.allowedPorts = portsForFirewall;
}
