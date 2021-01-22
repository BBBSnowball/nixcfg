{ stdenv, fetchurl, autoPatchelfHook, libstdcxx5, xorg, udev, qt4, libusb, ncurses5 }:
stdenv.mkDerivation {
  pname = "nrfjprog";
  version = "10.12.1";

  src = fetchurl {
    url = "https://www.nordicsemi.com/-/media/Software-and-other-downloads/Desktop-software/nRF-command-line-tools/sw/Versions-10-x-x/10-12-1/nRFCommandLineTools10121Linuxamd64tar.gz";
    sha256 = "sha256-uZVY3WMdt/Bv58+rCodtNShRu8HpcBVDJIZYi5yvgYQ=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    #libstdcxx5
    udev qt4 libusb ncurses5
  ] ++ (with xorg; [
    libICE
  ]);

  unpackPhase = ''
    tar -xf $src
    tar -xf JLink_Linux_V688a_x86_64.tgz
    tar -xf nRF-Command-Line-Tools_10_12_1.tar
  '';

  buildPhase = ''
  '';

  installPhase = ''
    mkdir -p $out/{bin,lib,include,share,share/nrfjprog/doc,share/mergehex/doc,share/jlink/doc}
    mv {mergehex,nrfjprog}/*.h $out/include/
    mv mergehex/*.txt $out/share/mergehex/doc
    mv nrfjprog/*.txt $out/share/nrfjprog/doc
    mv {mergehex,nrfjprog}/* $out/bin/
    mv JLink*/* $out/bin/
  '';

  # postFixup doesn't work here because it runs before autoPatchelfHook.
  preDistPhases = [ "fixup2" ];
  fixup2 = ''
    echo abc
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" --set-rpath $out/bin:$out/lib $out/bin/nrfjprog
    for x in $out/bin/libjlinkarm* ; do
      patchelf --set-rpath $out/bin:$out/lib:$(patchelf --print-rpath "$x") "$x"
    done
  '';
}
