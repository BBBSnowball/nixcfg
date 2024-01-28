{ stdenv, fetchFromGitHub, perl, gnumake }:
stdenv.mkDerivation rec {
  pname = "muninlite";
  version = "2.1.2";

  src = fetchFromGitHub {
    owner = "munin-monitoring";
    repo = pname;
    rev = version;
    hash = "sha256-yQ/IFZ5BKmRKYX8K78sswdnVVpzD/BhoJahYJW+iqBY=";
  };

  nativeBuildInputs = [ perl gnumake ];

  #PLUGINS = "df cpu if_ if_err_ load memory processes swap netstat uptime interrupts irqstats ntpdate wireless plugindir_";
  # remove ntpdate, wireless and plugindir_
  PLUGINS = "df cpu if_ if_err_ load memory processes swap netstat uptime interrupts irqstats";

  buildPhase = ''
    make

    # HaOS doesn't have `which` but its `/bin/sh` supports `command -v`.
    # `df` plugin uses the last name for partitions with bind mounts but we usually want the first one.
    substituteInPlace muninlite \
      --replace '$(which ' '$(command -v ' \
      --replace 'df -PT |' 'df -PT | tac |'
  '';

  installPhase = ''
    mkdir -p $out/bin
    mv muninlite $out/bin/muninlite
  '';

  # The resulting script should be portable so keep shebang as "/bin/sh".
  dontFixup = true;
}
