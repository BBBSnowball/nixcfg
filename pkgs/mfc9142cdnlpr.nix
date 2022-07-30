# copied from https://raw.githubusercontent.com/NixOS/nixpkgs/nixos-22.05/pkgs/misc/cups/drivers/mfc9140cdnlpr/default.nix, modified for 9142
{ stdenv
, lib
, fetchurl
, dpkg
, makeWrapper
, coreutils
, file
, gawk
, ghostscript
, gnused
, pkgsi686Linux
, a2ps
}:

stdenv.mkDerivation rec {
  pname = "mfc9142cdnlpr";
  version = "1.1.3-0";

  src = fetchurl {
    url = "https://download.brother.com/welcome/dlf101616/${pname}-${version}.i386.deb";
    sha256 = "sha256-HKEUPAdMM+z+DNwm61xebNmwu+lMEW/JwD1U3nowKd8=";
  };

  unpackPhase = ''
    dpkg-deb -x $src $out
  '';

  nativeBuildInputs = [
    dpkg
    makeWrapper
  ];

  dontBuild = true;

  installPhase = ''
    dir=$out/opt/brother/Printers/mfc9142cdn

    patchelf --set-interpreter ${pkgsi686Linux.glibc.out}/lib/ld-linux.so.2 $dir/lpd/brmfc9142cdnfilter

    wrapProgram $dir/inf/setupPrintcapij \
      --prefix PATH : ${lib.makeBinPath [
        coreutils
      ]}

    substituteInPlace $dir/inf/brmfc9142cdnfunc \
      --replace '{Letter}' '{A4}'
    substituteInPlace $dir/inf/brmfc9142cdnrc \
      --replace 'PageSize=Letter' 'PageSize=A4'

    substituteInPlace $dir/lpd/filtermfc9142cdn \
      --replace "BR_CFG_PATH=" "BR_CFG_PATH=\"$dir/\" #" \
      --replace "BR_LPD_PATH=" "BR_LPD_PATH=\"$dir/\" #"

    wrapProgram $dir/lpd/filtermfc9142cdn \
      --prefix PATH : ${lib.makeBinPath [
        coreutils
        file
        ghostscript
        gnused
        a2ps
      ]}

    substituteInPlace $dir/lpd/psconvertij2 \
      --replace '`which gs`' "${ghostscript}/bin/gs"

    wrapProgram $dir/lpd/psconvertij2 \
      --prefix PATH : ${lib.makeBinPath [
        gnused
        gawk
      ]}
  '';

  meta = with lib; {
    description = "Brother MFC-9142CDN LPR printer driver";
    homepage = "http://www.brother.com/";
    license = licenses.unfree;
    #maintainers = with maintainers; [ hexa ];
    platforms = [ "i686-linux" "x86_64-linux" ];
  };
}
