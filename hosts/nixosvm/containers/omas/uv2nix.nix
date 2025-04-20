{ pkgs ? import <nixpkgs> {} }:
with pkgs;
let inherit (pkgs) lib; in
rec {
  pyproject-nix-src = fetchFromGitHub {
    owner = "pyproject-nix";
    repo = "pyproject.nix";
    rev = "8063ec98edc459571d042a640b1c5e334ecfca1e";
    hash = "sha256-1GSaoubGtvsLRwoYwHjeKYq40tLwvuFFVhGrG8J9Oek=";
  };
  pyproject-nix = import pyproject-nix-src {
    inherit lib;
  };

  uv2nix-src = fetchFromGitHub {
    owner = "pyproject-nix";
    repo = "uv2nix";
    rev = "3583e037163491ecd833f1d5d3eedf3869543c5d";
    hash = "sha256-gt9JBkYjZAEvGwCG7RMAAAr0j2RsaRmOMj/vV0briXk=";
  };
  uv2nix = import uv2nix-src {
    inherit pyproject-nix lib;
  };

  pyproject-build-systems-src = fetchFromGitHub {
    owner = "pyproject-nix";
    repo = "build-system-pkgs";
    rev = "7dba6dbc73120e15b558754c26024f6c93015dd7";
    hash = "sha256-nysSwVVjG4hKoOjhjvE6U5lIKA8sEr1d1QzEfZsannU=";
  };
  pyproject-build-systems = import pyproject-build-systems-src {
    inherit pyproject-nix uv2nix lib;
  };
}
