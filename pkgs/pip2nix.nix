{ fetchFromGitHub, python3, python3Packages, stdenv, pkgs, nixpkgs }:
let
  src = fetchFromGitHub {
    owner = "nix-community";
    repo = "pip2nix";
    rev = "0bbd06bcc9cbb372624d75775d938bf028da9f78";  # master, 2022-12-03
    hash = "sha256-YpNCrm3FWXpbv92CHAnkhmjGYTRNun8Iw8q6sVWiaPA=";
  };
  pip2nix = import "${src}/release.nix" { inherit pkgs nixpkgs; };
in
  # Current nixpkgs has Python 3.10 by default but pip2nix doesn't have any attribute
  # for this, yet. We could use make-pip2nix but this isn't accessible here.
  pip2nix.pip2nix.python39
