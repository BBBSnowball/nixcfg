let p = (import <nixpkgs> {}); in
{ stdenv ? p.stdenv, fetchurl ? p.fetchurl, libmm ? p.callPackage ./libmm.nix {} }:
stdenv.mkDerivation rec {
  pname = "smstools";
  version = "3.1.21";
  src = fetchurl {
    url = "http://smstools3.kekekasvi.com/packages/smstools3-${version}.tar.gz";
    sha256 = "1110m7v0ajafrlq313msmvpmzp1hj9ncmzvv2w9wzxhn5g0a8sx2";
  };
  patches = [
    ./smstools3-with-stats.patch 
    ./smstools3-install-to-prefix.patch
  ];
  buildInputs = [ libmm ];
  postPatch = ''
    #sed -i '/CFLAGS += -D NOSTATS/ d' src/Makefile
    #sed -i '/makedir \/var\/spool/ d' install.sh
  '';
  preBuild = ''
    makeFlagsArray+=("PREFIX=$out" "BINDIR=$out/bin")
  '';
  pretInstall = ''
    mkdir $out/etc
    cp -r doc $out/doc
  '';
}
