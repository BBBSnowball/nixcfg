{ stdenv
, python3
, inkscape
}:
let
  name = "subraum";
  ppython = python3.withPackages (p: [ p.colour ]);
in
stdenv.mkDerivation {
  pname = "plymouth-${name}";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ ppython inkscape ];

  buildPhase = ''
    runHook preBuild

    #substituteInPlace *.plymouth --replace /usr/ $out/
    substituteInPlace *.plymouth --subst-var out

    python3 generate.py

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dt $out/share/plymouth/themes/${name} *.png *.plymouth *.script

    runHook postInstall
  '';
}
