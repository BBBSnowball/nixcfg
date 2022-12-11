{ lib, stdenv, fetchFromGitHub, cmake, libusb-compat-0_1 }:
let
in
  stdenv.mkDerivation {
    name = "openups";
    version = "1f7585ec-20220624";

    src = fetchFromGitHub {
      owner = "mini-box";
      repo = "ups";
      rev = "1f7585ecec1f9469a9404434dc2514b4a76193e0";
      hash = "sha256-skPNYzUKCaJcj+LrS/sER+DpHodZp99/DOke+9OHd7Y=";
    };

    nativeBuildInputs = [ cmake ];
    buildInputs = [ libusb-compat-0_1 ];
  }
