{ pkgs, config, lib, ... }:
{
  imports = [
    ./autossh.nix
    ./mumbleweb.nix
    ./dinge-info.nix
  ];
}
