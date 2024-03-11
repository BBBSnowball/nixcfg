{ lib, pkgs, config, private, ... }:
let
  privateCommon = if builtins.readDir private ? "common.nix"
    then import "${private}/common.nix"
    else lib.warn "common.nix is not available in private so we cannot add SSH config for sync host"
      { sync = { host = "localhost"; port = 1; }; };
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
