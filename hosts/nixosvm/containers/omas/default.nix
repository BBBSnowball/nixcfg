{ config, lib, modules, pkgs, privateForHost, secretForHost, ... }:
let
  inherit (privateForHost.sonline0) trueDomain;
  inherit (privateForHost.omas) smtpHost;
  ports = config.networking.firewall.allowedPorts;
  name = "omas";
  containerName = name;
  hostName = "ogr.${trueDomain}";
in {
  containers.${name} = {
    autoStart = true;
    config = { config, pkgs, ... }: let
    in {
      imports = [
        modules.container-common
        #./kanidm.nix
        ./lldap.nix
        ./mediawiki.nix
        ./nginx-ldap.nix
        ./nextcloud.nix
        ./postgresql.nix
        ./send-mail.nix
        #./wordpress.nix
      ];
      
      _module.args = {
        domain = hostName;
        inherit ports smtpHost;
      };

      services.nginx.virtualHosts."intern.${hostName}" = {
        root = "/var/www/html-intern";
        listen = [
          { addr = "0.0.0.0"; port = ports.omas-intern.port; }
        ];
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

  networking.firewall.allowedPorts.omas-wordpress = 8100;
  networking.firewall.allowedPorts.omas-intern = 8101;
  networking.firewall.allowedPorts.omas-nextcloud = 8102;
  networking.firewall.allowedPorts.omas-discourse = 8103;
  networking.firewall.allowedPorts.omas-wiki = 8104;
  networking.firewall.allowedPorts.omas-accounts = 8105;
}
