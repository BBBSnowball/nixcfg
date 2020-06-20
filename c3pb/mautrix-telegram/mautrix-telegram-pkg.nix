{ lib, stdenv, python3, pythonWithPkgs, fetchFromGitHub }:
let
  pillow = python3.pkgs.pillow.override {
    inherit (pythonWithPkgs.packages) pytest olefile;
    pytestrunner = pythonWithPkgs.packages.pytest-runner;
    #propagatedBuildInputs = with pythonWithPkgs.packages; [ olefile ];
  };
in python3.pkgs.buildPythonApplication rec {
  pname = "mautrix-telegram";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "c3pb";
    repo = pname;
    rev = "c3pb-v${version}";
    sha256 = "03597nx3nn368mls07zpb40324krwhd7mji86ak6hv5jmp9f9c2g";
  };

  #NOTE pillow is not added via pypi2nix because it breaks pypi2nix.
  propagatedBuildInputs = (builtins.attrValues pythonWithPkgs.packages) ++ [pillow];
  checkInputs = with pythonWithPkgs.packages; [pytest-runner pytest-mock pytest-asyncio pytest];
}
