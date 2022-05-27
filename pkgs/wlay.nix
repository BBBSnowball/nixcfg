{ stdenv, cmake, fetchFromGitHub
, wayland, wayland-scanner, pkg-config, extra-cmake-modules, libffi, glfw, libepoxy, xorg }:
stdenv.mkDerivation {
  pname = "wlay";
  version = "20220127-ed3160";

  src = fetchFromGitHub {
    owner = "atx";
    repo = "wlay";
    rev = "ed316060ac3ac122c0d3d8918293e19dfe9a6c90";
    hash = "sha256-Lu+EyoDHiXK9QzD4jdwbllCOCl2aEU+uK6/KxC2AUGQ=";
    fetchSubmodules = true;
  };

  buildInputs = [ wayland wayland-scanner libffi glfw libepoxy xorg.libX11 ];
  nativeBuildInputs = [ pkg-config cmake extra-cmake-modules ];
}

