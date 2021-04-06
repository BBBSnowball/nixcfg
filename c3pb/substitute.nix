pkgs: input: subs: pkgs.stdenv.mkDerivation {
  name = builtins.baseNameOf input;
  version = "1";
  src = input;
  dontUnpack = true;
  installPhase = ''
    substitute $src $out ${subs}
  '';
}
