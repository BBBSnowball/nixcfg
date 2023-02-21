{ config, lib, routeromen, private, ... }:
let
  #NOTE We are hardcoding the hostname here because we need the outer host and this is evaluated for the container.
  privateForHost = "${private}/by-host/nixosvm";
in
{
  imports = [
    routeromen.nixosModules.snowball-vm
    ./openssh-with-unix-socket.nix
  ];

  users.users.root.openssh.authorizedKeys.keyFiles = [ "${privateForHost}/ssh-laptop.pub" "${privateForHost}/ssh-dom0.pub" ];

  system.stateVersion = lib.mkDefault "22.11";
}
