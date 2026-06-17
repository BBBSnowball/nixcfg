{ ... }:

{
  imports = [
    #./loginctl-linger.nix
    ./desktop
    ./desktop/launcher.nix
    ./sway
    ./dotfiles.nix
    ./he-dns.nix
    ./kea.nix
    ./mobile-nixos-bootloader.nix
    ./spotifyd.nix
    ./terminal.nix

    # server
    #./webserver.nix
  ];
}
