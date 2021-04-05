{ config, pkgs, lib, ... }:
{
  nixpkgs.overlays = [ (import ./overlay.nix) ];
  environment.etc.abc.source = pkgs.edumeet-server;
}
