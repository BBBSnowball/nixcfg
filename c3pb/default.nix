{ pkgs, config, lib, ... }:
{
  imports = [
    ./autossh.nix
    ./mumbleweb.nix
  ];
}
