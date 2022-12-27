{ system ? builtins.currentSystem, pkgs ? import <nixpkgs> { inherit system; } }:
let
  # cadquery has been broken for a long time in nixpkgs because its Python deps broke so let's play it safe and pin nixpkgs
  nixpkgs = pkgs.fetchzip {
    url = https://github.com/NixOS/nixpkgs/archive/e8ec26f41fd94805d8fbf2552d8e7a449612c08e.tar.gz;
    hash = "sha256-3XuCP1b8U0/rzvQciowoM6sZjtq7nYzHOFUcNRa0WhY=";
  };
  pkgs2 = import nixpkgs { inherit system; };

  #FIXME This will already fail when evaluating .cadquery so we will never get to overrideAttrs.
  cadquery = pkgs2.python3Packages.cadquery.overrideAttrs (old: {
    name = old.pname;
    version = "";

    src = pkgs.fetchFromGitHub {
      owner = "CadQuery";
      repo = "cadquery";
      rev = "4568e45b153af4f33d74e558f6e50dc803c14a84";
    };

    disabled = false;  # can work with modern Python, now
  });

  cq-editor = pkgs2.cq-editor
    # undo fixing it to Python 3.7
    .override { python3Packages = pkgs2.python3Packages; }
    # and use newer sources
    .overrideAttrs (old: {
      name = old.pname;
      version = "";

      src = pkgs.fetchFromGitHub {
        owner = "CadQuery";
        repo = "cadquery";
        rev = "a2df6ffb04207aa22a177cab8f1ebad8ba974ab4";
      };

      propagatedBuildInputs = (builtins.filter (p: p.pname != "cadquery") old.propagatedBuildInputs) ++ [ cadquery ];
    });
in
  { inherit cadquery cq-editor; }
