{ fetchFromGitHub, python3, stdenv }:

#python3.pkgs.buildPythonApplication rec {  # Well, not really a Python package in the usual sense.
stdenv.mkDerivation rec {
  pname = "iproute2mac";
  version = "1.4.1";

  src = fetchFromGitHub {
    owner = "brona";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-MaL8eb9UOZ71BL4Jvc6Od+EJ+F6j96n9a+vRnHeveIU=";
  };

  buildInputs = [ python3 ];

  buildPhase = ''
    # optional - will use the system's Python 3 if we omit it
    patchShebangs src/ip.py
  '';

  installPhase = ''
    mkdir $out/bin -p
    cp src/ip.py $out/bin/ip
  '';
}

