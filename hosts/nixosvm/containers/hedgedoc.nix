{ lib, pkgs, config, modules, privateForHost, secretForHost, ... }:
let
  ports = config.networking.firewall.allowedPorts;
  name = "hedgedoc";
  domain = "writer.un${privateForHost.sonline0.trueDomain}";
  port = ports.${name}.port;
  secretFile = "${secretForHost}/${name}.env";
  secretFileInContainer = "/var/lib/nixos-containers/${name}${secretFile}";
in {
  containers.${name} = {
    autoStart = true;
    config = { config, pkgs, ... }: {
      imports = [ modules.container-common ];

      networking.firewall.allowedTCPPorts = [ port ];
    
      services.${name} = {
        enable = true;
        settings = {
          db.dialect = "sqlite";
          db.storage = "/var/lib/${name}/db.sqlite";
          domain = domain;
          protocolUseSSL = true;
          email = false;
          host = "::";
          port = port;
    
          # CDN cannot be loaded due to CSP because the integrity hashes seem to be wrong.
          # We don't want to use the CDN anyway...
          useCDN = false;
    
          gitlab.baseURL  = "https://git.c3pb.de/";
          gitlab.scope    = "read_user";
          # secrets are passed via environment
          gitlab.clientID = "";
          gitlab.clientSecret = "";
    
          allowFreeURL = true;
        };
      };
      # ##contains CMD_OAUTH2_CLIENT_ID and CMD_OAUTH2_CLIENT_SECRET for OpenID (from Gitlab)
      # contains CMD_GITLAB_CLIENTID and CMD_GITLAB_CLIENTSECRET for GitLab login (from Gitlab)
      # and CMD_SESSION_SECRET (random value, e.g. `pwgen -s 40 1`)
      systemd.services.${name}.serviceConfig.EnvironmentFile = secretFile;
    };
  };

  systemd.services."container@${name}".serviceConfig = {
    ExecStartPre = "${pkgs.coreutils}/bin/install -m 0700 -d ${builtins.dirOf secretFileInContainer}";
    BindReadOnlyPaths = "${secretFile}:${secretFileInContainer}";
  };

  networking.firewall.allowedPorts.${name} = 8089;
}
