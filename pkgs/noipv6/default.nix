{ stdenv, python3 }:
stdenv.mkDerivation rec {
  name = "noipv6.so";

  src = ./noipv6.c;
  dontUnpack = true;

  nativeBuildInputs = [ python3 ];

  buildPhase = ''
    gcc -shared -fPIC -o ${name}.so $src -ldl
  '';

  installPhase = ''
    cp ${name}.so $out
  '';

  # We cannot really check it in a builder because we don't have enough access to networking.
  doInstallCheck = false;
  installCheckPhase = ''
    a="$(python -c 'import socket; print([x[4][0] for x in socket.getaddrinfo("localhost", 0, type=socket.SocketKind.SOCK_STREAM)])')"
    echo "Normal: $a"
    b="$(LD_PRELOAD=$out python -c 'import socket; print([x[4][0] for x in socket.getaddrinfo("localhost", 0, type=socket.SocketKind.SOCK_STREAM)])')"
    echo "Only legacy IP: $b"
    if [ "$a" == "$b" -o "$b != "['127.0.0.1']" ] ; then
      echo "Result is not as expected!" >&2
      exit 1
    fi
  '';

  meta.description = "library for disabling IPv6 via LD_PRELOAD";
}
