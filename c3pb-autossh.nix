{ pkgs, config, lib, ... }:
{
  services.autossh.sessions = [
    {
      name = "amqp";
      user = "autossh";
      extraArguments = "-o BatchMode=yes -o ServerAliveInterval=60 -o ServerAliveCountMax=3 ${lib.fileContents ./private/autossh-target-hackerspace.txt} -NL 5672:amqp:5672";
    }
    {
      name = "ldap";
      user = "autossh";
      extraArguments = "-o BatchMode=yes -o ServerAliveInterval=60 -o ServerAliveCountMax=3 ${lib.fileContents ./private/autossh-target-ldap.txt} -NL 3890:localhost:389 -L 6360:localhost:636";
    }
  ];
  systemd.services.autossh-amqp.serviceConfig.Restart = lib.mkForce "always";
  systemd.services.autossh-amqp.serviceConfig.RestartSec = 10;
  systemd.services.autossh-ldap.serviceConfig.Restart = lib.mkForce "always";
  systemd.services.autossh-ldap.serviceConfig.RestartSec = 10;

  programs.ssh.extraConfig = lib.fileContents ./private/autossh-ssh-config;
  programs.ssh.knownHosts = import ./private/autossh-knownhosts.nix;

  users.users.autossh = {
    isNormalUser = false;
    #home = "/home/autossh";
    # Shell is required because ssh must be able to spawn a child for ProxyJump and it is using a shell for that.
    shell = pkgs.bash;
  };
}
