{ routeromen, private, ... }:
{
  imports = [
    routeromen.nixosModules.snowball-vm
    ./openssh-with-unix-socket.nix
  ];

  users.users.root.openssh.authorizedKeys.keyFiles = [ "${private}/ssh-laptop.pub" "${private}/ssh-dom0.pub" ];
}
