{stdenv, fetchFromGitHub, hidapi, tree}:
stdenv.mkDerivation {
  pname = "g810-led";
  version = "0.4.2";

  src = fetchFromGitHub {
    owner = "MatMoul";
    repo = "g810-led";
    rev = "5ee810a520f809e65048de8a8ce24bac0ce34490";
    sha256 = "1ymkp7i7nc1ig2r19wz0pcxfnpawkjkgq7vrz6801xz428cqwmhl";
  };
  
  makeFlags = ["DESTDIR=$(out)" "PREFIX=$(out)"];
  
  buildInputs = [hidapi];
  nativeBuildInputs = [tree];

  installPhase = ''
    mkdir -p $out/bin
    cp bin/g810-led $out/bin/
  '';
}
