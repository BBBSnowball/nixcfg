{ fetchFromGitHub, python3Packages, autoPatchelfHook, bash, nix, mkShell, stdenv, coreutils }:
let
  newWheel = python3Packages.buildPythonPackage rec {
    pname = "wheel";
    version = "0.36.2";
    src = fetchFromGitHub {
      owner = "pypa";
      repo = "wheel";
      rev = version;
      sha256 = "sha256-8lK2UvqBIxUYm6IOuT+Jk71wYbEEjvI7typS3749N9g=";
    };

    pythonImportsCheck = [ "wheel" ];

    pipInstallFlags = [ "--ignore-installed" ];
  };
in
python3Packages.buildPythonPackage rec {
  pname = "apio";
  version = "6.0.0";

  src = fetchFromGitHub {
    owner = "FPGAwars";
    repo = "apio";
    rev = "v6.0.0";
    sha256 = "sha256-8x3LErViXQ6iwegFkEWrGl9JcEZpRdNjUo1uVu7clu8=";
  };

  buildInputs = with python3Packages; [ pytest ];

  propagatedBuildInputs = with python3Packages; [
    click semantic-version requests pyjwt colorama pyserial newWheel
    setuptools
  ];

  PYTHONPATH = "${newWheel}/lib/python3.8/site-packages";

  passthru.wheel = newWheel;

  patches = [ ./apio.patch ];

  inherit autoPatchelfHook bash nix coreutils;
  autoPatchShell = builtins.unsafeDiscardOutputDependency (mkShell { buildInputs = [ stdenv autoPatchelfHook ]; }).drvPath;

  postPatch = ''
    substituteInPlace apio/nixos.py.sh --subst-var autoPatchelfHook --subst-var bash --subst-var nix --subst-var autoPatchShell --subst-var coreutils
  '';

  postInstall = ''
    chmod +x apio/nixos.py.sh
    cp apio/nixos.py.sh $out/lib/python*/site-packages/apio/
  '';
}
