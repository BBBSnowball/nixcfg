{ lib, stdenv, fetchFromGitHub, libusb1, cmake, pkg-config
, qmake, qtbase, qtquickcontrols2, qtmultimedia, wrapQtAppsHook }:
let
  libuvc = stdenv.mkDerivation {
    name = "libuvc-getthermal";
    version = "0.1";

    src = fetchFromGitHub {
      owner = "groupgets";
      repo = "libuvc";
      rev = "5e866910de3f172bd5adab72baec40a066bbbe3a";
      hash = "sha256-aJXRR7JSONI3fNNGmnihCsIGw3Mn1Q6Ioz0gz67S1yE=";
    };

    buildInputs = [ libusb1 ];
    nativeBuildInputs = [ cmake ];

    postInstall = ''
      cp libuvcstatic.a $out/lib
    '';
  };
in
  stdenv.mkDerivation {
    pname = "GetThermal";
    version = "0.1.4";

    src = fetchFromGitHub {
      owner = "groupgets";
      repo = "GetThermal";
      rev = "v0.1.4";
      hash = "sha256-WoogUjAGm0vmz2WwIFos9kLpRko+tAqqtl6HOhzxFQY=";
    };

    passthru.libuvc = libuvc;

    nativeBuildInputs = [ pkg-config qmake qtbase wrapQtAppsHook ];
    buildInputs = [ libuvc libusb1 qtquickcontrols2 qtmultimedia ];

    preConfigure = ''
      # GetThermal project insists that we use "shadow build", i.e. in a subdirectory.
      mkdir build
      cd build
      qmakeFlags+=(../GetThermal.pro)
    '';

    installPhase = ''
      mkdir $out/bin -p
      cp release/GetThermal $out/bin/
    '';
  }
