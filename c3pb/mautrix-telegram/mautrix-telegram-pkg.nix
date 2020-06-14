{ lib, stdenv, python3, pythonWithPkgs, fetchFromGitHub }:
buildPythonApplication rec {
  pname = "mautrix-telegram";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "c3pb";
    repo = pname;
    rev = "c3pb-v${version}";
    sha256 = "03597nx3nn368mls07zpb40324krwhd7mji86ak6hv5jmp9f9c2g";
  };

  #NOTE pillow is not added via pypi2nix because it breaks pypi2nix.
  propagatedBuildInputs = builtins.attrValues pythonWithPkgs.packages;
  checkInputs = with pythonWithPkgs.packages; [pytestrunner pytest-mock pytest-asyncio pytest];
}
