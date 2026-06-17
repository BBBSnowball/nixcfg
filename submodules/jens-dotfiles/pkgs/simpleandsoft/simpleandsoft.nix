{ stdenv, fetchurl, writeTextFile, tree }:
stdenv.mkDerivation rec {
  # Cursor theme "Simple and Soft" from https://store.kde.org/p/999946/
  pname = "simpleandsoft";
  version = "0.2";

  src = ./28427-simpleandsoft-0.2.tar.gz;

  indexTheme = ''
    [Icon Theme]
    Name=Simple-and-Soft
    Comment=A simple and soft X cursor theme
    Example=left_ptr_watch
  '';
  passAsFile = [ "indexTheme" ];

  buildInputs = [ tree ];

  installPhase = ''
    mkdir -p "$out/share/icons/Simple-and-Soft"
    tree
    cp -R "cursors" "$out/share/icons/Simple-and-Soft/cursors"
    install -Dm644 "$indexThemePath" "$out/share/icons/Simple-and-Soft/index.theme"
  '';
}