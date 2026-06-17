{ stdenv, fetchFromGitHub, meson, pkgconfig, ninja, libdrm, gettext, glib, appstream-glib, python3 }:

stdenv.mkDerivation {
  pname = "siglo";
  version = "unstable";

  src = fetchFromGitHub {
    owner = "alexr4535";
    repo = "siglo";
    rev = "v0.8.13";
    sha256 = "sha256-EMnCkXYyuZ9jeXxrTZGGZzS/w94knbZoZF5xo/27mas=";
  };

  nativeBuildInputs = [ meson ninja pkgconfig ];
  buildInputs = [
    gettext
    glib
    appstream-glib
    python3
  ];
}
