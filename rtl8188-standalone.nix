{ pkgs ? import <nixpkgs> {} }:
pkgs.callPackage (import ./rtl8188.nix) { kernel = pkgs.linux; }
