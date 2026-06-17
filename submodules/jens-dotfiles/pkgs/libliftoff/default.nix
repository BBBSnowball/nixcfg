{ stdenv, fetchFromGitHub, meson, pkgconfig, ninja, libdrm }:

stdenv.mkDerivation {
  pname = "gamescope";
  version = "git";

  src = fetchFromGitHub {
    owner = "emersion";
    repo = "libliftoff";
    rev = "93a346ff95fa6a121b90531445bce27aa207e4b7";
    sha256 = "113p4fjb30zh7zxz672fz4jxj0hl0bzh1nyvxqa6rrqk7iwmxxn5";
  };

  nativeBuildInputs = [ meson ninja pkgconfig ];
  buildInputs = [
    libdrm
  ];
}
