{ pkgs ? import <nixpkgs> { }
, theme ? "subraum"
, # TODO: Should be a list when more themes come
  bgColor ? "1, 1, 1"
, # rgb value between 0-1. TODO: Write hex to plymouth magic
}:
pkgs.stdenv.mkDerivation {
  pname = "plymouth-whatever";
  version = "0.1.0";

  src = ./src;

  patchPhase = ''
    runHook prePatch

    shopt -s extglob

    # deal with all the non ascii stuff

    runHook postPatch
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/plymouth/themes/${theme}
    cp ${theme}/* $out/share/plymouth/themes/${theme}
    find $out/share/plymouth/themes/ -name \*.plymouth -exec sed -i "s@\/usr\/@$out\/@" {} \;

    runHook postInstall
  '';
}
