{ config, lib, modules, pkgs, privateForHost, secretForHost, mainFlake, flohmarkt, ... }:
let
  name = "flohmarkt";
  inherit (privateForHost.${name}) domain;
  containerName = name;
  hostName = domain;

  ports = let x = port: { inherit port; type = "tcp"; }; in {
    flohmarkt = x 8204;
  };
  portsForFirewall = {
    inherit (ports) flohmarkt;
  };

  #NOTE Set to false after first deployment
  #     (because we would rather not start at all when the database is missing later for whatever reason)
  createDatabase = true;

  hostAddress = "192.168.7.1";  # We cannot add a prefix length because init script also uses it for the gateway.
  localAddress = "192.168.7.2";
in {
  containers.${name} = {
    autoStart = true;
    config = { config, pkgs, ... }: let
    in {
      imports = [
        mainFlake.nixosModules.allowUnfree
        mainFlake.nixosModules.sendmail
        modules.container-common
        flohmarkt.nixosModules.default
        ./flohmarkt.nix
        ./send-mail.nix
      ];
      
      _module.args = {
        inherit ports domain createDatabase flohmarkt localAddress;
        inherit (privateForHost.${name}) smtpHost reverse_proxy_ip;
        privateForContainer = privateForHost.${name};
      };

      systemd.services.nginx.serviceConfig.LogsDirectoryMode = lib.mkForce "0700";

      security.sudo.execWheelOnly = true;
      # allow running in different directory for root (`sudo -D /mydir`)
      security.sudo.extraConfig = ''
        Defaults:root,%wheel runcwd=*
      '';

      # container has its own firewall due to privateNetwork=true
      networking.firewall.allowedTCPPorts = [ ports.flohmarkt.port ];
    };

    # This doesn't support directories, it seems.
    #extraFlags = [ "--load-credential=secret:${secretForHost}/${name}/" ];
    # Bind-mount the credentials to one of the paths where systemd will look by default.
    bindMounts."/run/credstore".hostPath = "/run/credentials/container@${containerName}.service";

    privateNetwork = true;
    inherit localAddress hostAddress;
    forwardPorts = [ { hostPort = ports.flohmarkt.port; } ];
    #NOTE We have added some nftables rules in firewall-nftables.nix.
  };

  systemd.services."container@${containerName}".serviceConfig.LoadCredential = [ "secret:${secretForHost}/${name}/" ];

  networking.firewall.allowedPorts = portsForFirewall;
}
