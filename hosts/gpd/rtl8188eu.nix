{ stdenv, lib, fetchFromGitHub, kernel, bc }:


let modDestDir = "$out/lib/modules/${kernel.modDirVersion}/kernel/drivers/net/wireless/realtek/rtl8188eu";

in stdenv.mkDerivation rec {
  name = "r8188eu-${kernel.version}-${version}";
  # on update please verify that the source matches the realtek version
  version = "1.0";

  src = fetchFromGitHub {
    owner = "lwfinger";
    repo = "rtl8188eu";
    rev = "c9280272bcc358e52d57b3f88e42596795b8f6c1";
    sha256 = "sha256-5wrm0IFR+nnouFqA6sYw2LkrUuSIuptUbDQQ+zZCw88=";
  };

  hardeningDisable = [ "pic" ];

  nativeBuildInputs = kernel.moduleBuildDependencies ++ [ bc ];

  preBuild = ''
    makeFlagsArray+=("KVER=${kernel.modDirVersion}")
    makeFlagsArray+=("KSRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build")
    makeFlagsArray+=("modules")
  '';

  enableParallelBuilding = true;

  installPhase = ''
    mkdir -p ${modDestDir}
    find . -name '*.ko' -exec cp --parents '{}' ${modDestDir} \;
    find ${modDestDir} -name '*.ko' -exec xz -f '{}' \;
  '';

  meta = with lib; {
    description = "Realtek RTL8188EU driver";
    longDescription = ''
      A kernel module for Realtek 8188 network cards.
    '';
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
  };
}
