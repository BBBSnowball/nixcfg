# nixpkgs=$(nix eval --impure --expr 'with builtins; let x = getFlake (toString ../../..); in x.inputs.nixpkgs.outPath' --raw)
# nix-build test.nix -I nixpkgs=$nixpkgs
{ pkgs ? import <nixpkgs> {} }:
let
  privateForHost = {
    serverExternalIp = "1.2.3.4";
  };
  overlay = import ../overlay.nix privateForHost;
  pkgs2 = pkgs // overlay pkgs2 pkgs;
in
{
  inherit (pkgs2) edumeet-app edumeet-server;
}
