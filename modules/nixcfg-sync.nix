{ lib, pkgs, config, private, ... }:
let
  privateCommon = if builtins.readDir private ? "common.nix"
    then import "${private}/common.nix"
    else lib.warn "common.nix is not available in private so we cannot add SSH config for sync host"
      { sync = { host = "localhost"; port = 1; }; };
in
{
  environment.systemPackages = with pkgs; [
    gnupg git-crypt
  ];

  #NOTE This will use gitFull by default but can be changed with programs.git.package.
  # (If we were to unconditionally add git to systemPackages, this would conflict with gitFull.)
  programs.git.enable = true;

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
