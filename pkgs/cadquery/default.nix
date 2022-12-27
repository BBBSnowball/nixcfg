{ system ? builtins.currentSystem, pkgs ? import <nixpkgs> { inherit system; } }:
let
  # cadquery has been broken for a long time in nixpkgs because its Python deps broke so let's play it safe and pin nixpkgs
  nixpkgs = pkgs.fetchzip {
    url = https://github.com/NixOS/nixpkgs/archive/e8ec26f41fd94805d8fbf2552d8e7a449612c08e.tar.gz;
    hash = "sha256-3XuCP1b8U0/rzvQciowoM6sZjtq7nYzHOFUcNRa0WhY=";
  };

  pkgs2 = import nixpkgs {
    inherit system;

    overlays = [ (final: prev: {
      # don't override python3Packages because it should work with modern Python, now
      cq-editor = final.libsForQt5.callPackage ./cq-editor.nix { };

      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [ (python-final: python-prev: {
        cadquery = python-final.callPackage ./cadquery.nix {
          inherit (final.darwin.apple_sdk.frameworks) Cocoa;
        };
      }) ];

      cadquery-server = final.python3Packages.callPackage ./cadquery-server.nix { };
    }) ];
  };

  cadquery = pkgs2.python3Packages.cadquery;
in
  cadquery // {
    pkgs = pkgs2;
    inherit (pkgs2) cq-editor cadquery-server;
    python3 = pkgs2.python3.withPackages (p: [ p.cadquery ]);
  }
