{
  stdenv
, python3
, runCommand
, gtk3
, wrapGAppsHook3
, gobject-introspection
}:
stdenv.mkDerivation {
  name = "add_recently_used";
  src = null;
  dontUnpack = true;

  buildInputs = [
    (python3.withPackages (p: [ p.pygobject3 ]))
    gtk3
  ];

  nativeBuildInputs = [ wrapGAppsHook3 gobject-introspection ];

  installPhase = ''
    mkdir -p $out/bin
    cp ${./add_recently_used.py} $out/bin/add_recently_used
    patchShebangs $out/bin/add_recently_used
  '';
}
