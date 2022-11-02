{ pkg ? ./rtl8188.nix, pkgs ? import <nixpkgs> {} }:
pkgs.callPackage (import pkg) { kernel = pkgs.linux; }
