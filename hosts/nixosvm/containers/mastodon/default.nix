{ config, lib, modules, pkgs, privateForHost, secretForHost, routeromen, ... }:
let
  name = "mastodon";
  inherit (privateForHost.${name}) domain;
  containerName = name;
  hostName = domain;

  ports = let x = port: { inherit port; type = "tcp"; }; in {
    mastodon = x 8200;
    webPort = x 55001;
    sidekiqPort = x 55002;
    elasticsearch = x 8201;
    elasticsearch-internal = x 8202;
  };
  portsForFirewall = {
    inherit (ports) mastodon;
  };

  #NOTE Set to false after first deployment
  #     (because we would rather not start at all when the database is missing later for whatever reason)
  createDatabase = false;
in {
  containers.${name} = {
    autoStart = true;
    config = { config, pkgs, ... }: let
    in {
      imports = [
        routeromen.nixosModules.allowUnfree
        modules.container-common
        ./elasticsearch.nix
        ./mastodon.nix
        ./nginx-logging.nix
        ./postgresql.nix
        ./send-mail.nix
      ];
      
      _module.args = {
        inherit ports domain createDatabase;
        inherit (privateForHost.${name}) smtpHost reverse_proxy_ip;
      };

      systemd.services.nginx.serviceConfig.LogsDirectoryMode = lib.mkForce "0700";

      security.sudo.execWheelOnly = true;
      # allow running in different directory for root (`sudo -D /mydir`)
      security.sudo.extraConfig = ''
        Defaults:root,%wheel runcwd=*
      '';
    };

    # This doesn't support directories, it seems.
    #extraFlags = [ "--load-credential=secret:${secretForHost}/${name}/" ];
    # Bind-mount the credentials to one of the paths where systemd will look by default.
    bindMounts."/run/credstore".hostPath = "/run/credentials/container@${containerName}.service";

    # Postgres migration and ElasticSearch setup can take a long time.
    timeoutStartSec = "11min";
  };

  systemd.services."container@${containerName}".serviceConfig.LoadCredential = [ "secret:${secretForHost}/${name}/" ];

  networking.firewall.allowedPorts = portsForFirewall;

  # make tootctl available on the host
  # (needs `sudo -D`, see above)
  environment.systemPackages = [ (pkgs.writeShellScriptBin "mastodon-tootctl" ''
    nixos-container run mastodon -- sudo -Hu mastodon -D / mastodon-tootctl "$@"
  '') ];
}
