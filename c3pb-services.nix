{ pkgs, config, lib, ... }:
{
  imports = [
    ./c3pb-autossh.nix
    ./c3pb-mumbleweb.nix
  ];
}
