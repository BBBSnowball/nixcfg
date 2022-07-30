# copied from https://raw.githubusercontent.com/NixOS/nixpkgs/nixos-22.05/pkgs/misc/cups/drivers/mfc9140cdncupswrapper/default.nix, modified for 9142
{ lib
, stdenv
, fetchurl
, dpkg
, makeWrapper
, coreutils
, gnugrep
, gnused
, mfc9142cdnlpr
, pkgsi686Linux
, psutils
}:

stdenv.mkDerivation rec {
  pname = "mfc9142cdncupswrapper";
  version = "1.1.4-0";

  src = fetchurl {
    url = "https://download.brother.com/welcome/dlf101617/${pname}-${version}.i386.deb";
    sha256 = "sha256-RHLQrvQUjqzm2N+HOwPrGpGSJ5HkUekNet3eTjfIduI=";
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
    lpr=${mfc9142cdnlpr}/opt/brother/Printers/mfc9142cdn
    dir=$out/opt/brother/Printers/mfc9142cdn

    interpreter=${pkgsi686Linux.glibc.out}/lib/ld-linux.so.2
    patchelf --set-interpreter "$interpreter" "$dir/cupswrapper/brcupsconfpt1"

    substituteInPlace $dir/cupswrapper/cupswrappermfc9142cdn \
      --replace "mkdir -p /usr" ": # mkdir -p /usr" \
      --replace '/opt/brother/''${device_model}/''${printer_model}/lpd/filter''${printer_model}' "$lpr/lpd/filtermfc9142cdn" \
      --replace '/usr/share/ppd/Brother/brother_''${printer_model}_printer_en.ppd' "$dir/cupswrapper/brother_mfc9142cdn_printer_en.ppd" \
      --replace '/usr/share/cups/model/Brother/brother_''${printer_model}_printer_en.ppd' "$dir/cupswrapper/brother_mfc9142cdn_printer_en.ppd" \
      --replace '/opt/brother/Printers/''${printer_model}/' "$lpr/" \
      --replace 'nup="psnup' "nup=\"${psutils}/bin/psnup" \
      --replace '/usr/bin/psnup' "${psutils}/bin/psnup"
    #  --replace 'DEBUG=0' 'DEBUG=8' \
    #  --replace 'LOGFILE="/dev/null"' 'LOGFILE="/tmp/brlog"'

    mkdir -p $out/lib/cups/filter
    mkdir -p $out/share/cups/model

    ln $dir/cupswrapper/cupswrappermfc9142cdn $out/lib/cups/filter
    ln $dir/cupswrapper/brother_mfc9142cdn_printer_en.ppd $out/share/cups/model

    sed -n '/!ENDOFWFILTER!/,/!ENDOFWFILTER!/p' "$dir/cupswrapper/cupswrappermfc9142cdn" | sed '1 br; b; :r s/.*/printer_model=mfc9142cdn; cat <<!ENDOFWFILTER!/'  | bash > $out/lib/cups/filter/brother_lpdwrapper_mfc9142cdn
    sed -i "/#! \/bin\/sh/a PATH=${lib.makeBinPath [ coreutils gnused gnugrep ]}:\$PATH" $out/lib/cups/filter/brother_lpdwrapper_mfc9142cdn
    chmod +x $out/lib/cups/filter/brother_lpdwrapper_mfc9142cdn

    # workaround: ELF opens 0600-k_cache12.bin from absolute path that is hardcoded in the binary or from current directory
    # (The hardcoded path would be /opt/brother/Printers/mfc9142cdn/inf/lut/0600-k_cache12.bin)
    substituteInPlace $out/lib/cups/filter/brother_lpdwrapper_mfc9142cdn \
      --replace 'LOG_LATESTONLY=1' "`echo -e "LOG_LATESTONLY=1\ncd $lpr/inf/lut"`"
    '';

  meta = with lib; {
    description = "Brother MFC-9142CDN CUPS wrapper driver";
    homepage = "http://www.brother.com/";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    #maintainers = with maintainers; [ hexa ];
  };
}
