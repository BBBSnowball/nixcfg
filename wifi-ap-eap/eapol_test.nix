{ pkgs ? import <nixpkgs> {} }:
pkgs.wpa_supplicant.overrideAttrs (old: rec {
  pname = "eapol_test";
  name = "${pname}-${old.version}";
  makeFlags = "eapol_test";
  installPhase = ''
    mkdir $out $out/bin
    install eapol_test $out/bin/
  '';
})
