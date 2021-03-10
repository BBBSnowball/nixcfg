{ pkgs, lib, ... }:
let
  sshConfigHackerspace = pkgs.writeText "ssh-config-hackerspace" ''
    Host hackerspace.c3pb.de
        PubkeyAuthentication yes
        IdentityFile /etc/nixos/secret/autossh/id_hackerspace
        IdentitiesOnly yes

        BatchMode yes
        ServerAliveInterval 60
        ServerAliveCountMax 3
  '';
in {
  services.autossh.sessions = [
    {
      name = "hackerspace";
      user = "autossh";
      extraArguments = "-M 10001 -F ${sshConfigHackerspace} snowball@hackerspace.c3pb.de -NR 10000:localhost:22";
    }
  ];

  systemd.services.autossh-hackerspace.serviceConfig.Restart = lib.mkForce "always";
  systemd.services.autossh-hackerspace.serviceConfig.RestartSec = 10;

  programs.ssh.knownHosts = {
    hackerspace = { hostNames = ["hackerspace.c3pb.de" "94.79.177.226"];
      publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBMrEDQuL+e2KsBueCV9bbDrIM+05X4DJMvyTzps3qfQXyWFTcn+WsQOrM3rg3/gVvYyUBXntYrqX7YzpwMlRRjA="; };
  };

  users.users.autossh = {
    isNormalUser = false;
    # Shell is required because ssh must be able to spawn a child for ProxyJump and it is using a shell for that.
    shell = pkgs.bash;
  };
}
