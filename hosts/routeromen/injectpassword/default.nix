{ pkgs ? import <nixpkgs> {} }:
with pkgs;
stdenv.mkDerivation {
  name = "injectpassword";
  src = ./.;

  buildPhase = ''
    gcc -O2 -fPIC -shared -o injectpassword.so injectpassword.c -ldl
  '';

  installPhase = ''
    mkdir $out
    cp injectpassword.so $out
  '';
}
