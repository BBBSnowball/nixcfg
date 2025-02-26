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

          # "email" is for local accounts with password
          email = true;
          allowEmailRegister = false;

          allowFreeURL = true;
          requireFreeURLAuthentication = true;
        };
      };
      # ##contains CMD_OAUTH2_CLIENT_ID and CMD_OAUTH2_CLIENT_SECRET for OpenID (from Gitlab)
      # contains CMD_GITLAB_CLIENTID and CMD_GITLAB_CLIENTSECRET for GitLab login (from Gitlab)
      # and CMD_SESSION_SECRET (random value, e.g. `pwgen -s 40 1`)
      systemd.services.${name}.serviceConfig.EnvironmentFile = secretFile;

      environment.systemPackages = let
        manage = pkgs.writeShellScriptBin "hedgedoc-manage-users" ''
          exec sudo -u hedgedoc -- hedgedoc-manage-users-inner "$@"
        '';
        # also added to the system because the user doesn't have a shell, so we cannot easily get to its PATH
        pkg = config.services.${name}.package;
        manage-inner = pkgs.writeShellScriptBin "hedgedoc-manage-users-inner" ''
          # enable verbose debug info because user errors ("not an email") and even hard exceptions will be swallowed without that
          export NODE_DEBUG="*"
          export CMD_CONFIG_FILE=/run/hedgedoc/config.json
          export NODE_ENV=production
          exec ${pkg}/bin/manage_users "$@"
        '';
      in [ manage manage-inner ];
    };
  };

  systemd.services."container@${name}".serviceConfig = {
    ExecStartPre = "${pkgs.coreutils}/bin/install -m 0700 -d ${builtins.dirOf secretFileInContainer}";
    BindReadOnlyPaths = "${secretFile}:${secretFileInContainer}";
  };

  networking.firewall.allowedPorts.${name} = 8089;

  # This would be nice to have but it runs the command without a tty, which won't work for the password prompt.
  #environment.systemPackages = let
  #  manage = pkgs.writeShellScriptBin "hedgedoc-manage-users" ''
  #    exec nixos-container run hedgedoc -- sudo -u hedgedoc -- hedgedoc-manage-users-inner "$@"
  #  '';
  #in [ manage ];
}
