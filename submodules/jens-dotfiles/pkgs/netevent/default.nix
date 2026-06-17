{ stdenv, fetchFromGitHub, docutils, zsh }:
stdenv.mkDerivation rec {
  pname = "netevent";
  version = "git";

  src = fetchFromGitHub {
    owner = "Blub";
    repo = "netevent";
    rev = "ddd330f0dc956a95a111c58ad10546071058e4c1";
    sha256 = "0myk91pmim0m51h4b8hplkbxvns0icvfmv0401r0hw8md828nh5c";
  };

  depsBuildBuild = [ docutils zsh ];

  configurePhase = ''
    # running configure with zsh, otherwise 'which' is not available
    zsh ./configure --enable-doc --prefix=/
  '';

  installPhase = ''
    make DESTDIR="$out" install
  '';
}
