let p = (import <nixpkgs> {}); in
{ stdenv ? p.stdenv, fetchurl ? p.fetchurl }:
stdenv.mkDerivation rec {
  pname = "libmm";
  version = "1.4.2";
  src = fetchurl {
    url = "http://smstools3.kekekasvi.com/packages/mm-${version}.tar.gz";
    sha256 = "11aq6948c897zj3pdc957yi6xmyl2nzckvbz9c77kiyqx0gdvbcc";
  };
}
