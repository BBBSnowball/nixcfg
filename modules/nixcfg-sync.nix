{ pkgs, config, private, ... }:
let
  privateCommon = import "${private}/common.nix";
in
{
  environment.systemPackages = with pkgs; [
    git gnupg git-crypt
  ];

  programs.ssh.extraConfig = ''
    Host sync
      HostName ${privateCommon.sync.host}
      Port ${toString privateCommon.sync.port}
      User git
      IdentitiesOnly yes
      PubkeyAuthentication yes
      IdentityFile /etc/nixos/secret_local/hostkeys/id_rsa
  '';
}
