{ pkgs, config, lib, privateForHost, secretForHost, ... }:
{
  services.autossh.sessions = [
    {
      name = "amqp";
      user = "autossh";
      monitoringPort = 29485;
      extraArguments = "-o BatchMode=yes -o ServerAliveInterval=60 -o ServerAliveCountMax=3 hackerspace -NL 5672:amqp:5672";
    }
    #{
    #  name = "ldap";
    #  user = "autossh";
    #  monitoringPort = 37512;
    #  extraArguments = "-o BatchMode=yes -o ServerAliveInterval=60 -o ServerAliveCountMax=3 ldap-tunnel -NL 3890:localhost:389 -L 6360:localhost:636";
    #}
  ];
  systemd.services = let
    restartConfig = {
      Restart = lib.mkForce "always";
      RestartSec = 10;
    };
  in {
    autossh-amqp = {
      serviceConfig = restartConfig // {
        LoadCredential = "id_edi:${secretForHost}/autossh/id_edi";
        RuntimeDirectory = "autossh";
        WorkingDirectory = "/run/autossh";
      };
      preStart = ''
        ln -sf ''${CREDENTIALS_DIRECTORY}/id_edi /run/autossh/
      '';
    };
    autossh-ldap.serviceConfig = restartConfig;
  };

  # The ssh config refers to the IdentityFile in /etc/nixos/secret (for use by root) as well as /run/autossh (for use by the service).
  programs.ssh.extraConfig = lib.fileContents "${privateForHost}/autossh-ssh-config";
  programs.ssh.knownHosts = import "${privateForHost}/autossh-knownhosts.nix";

  users.users.autossh = {
    #home = "/home/autossh";
    # Shell is required because ssh must be able to spawn a child for ProxyJump and it is using a shell for that.
    shell = pkgs.bash;
    isSystemUser = true;
    group = "autossh";
  };
  users.groups.autossh = {};
}
