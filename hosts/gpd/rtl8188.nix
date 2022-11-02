{ stdenv, lib, fetchFromGitHub, kernel, bc }:


let modDestDir = "$out/lib/modules/${kernel.modDirVersion}/kernel/drivers/net/wireless/realtek/rtl8821cu";

in stdenv.mkDerivation rec {
  name = "r8188-${kernel.version}-${version}";
  # on update please verify that the source matches the realtek version
  version = "5.4.1";

  src = fetchFromGitHub {
    owner = "brektrou";
    repo = "rtl8821CU";
    rev = "45a8b4393e3281b969822c81bd93bdb731d58472";
    sha256 = "1995zs1hvlxjhbh2w7zkwr824z19cgc91s00g7yhm5d7zjav14rd";
  };

  hardeningDisable = [ "pic" ];

  nativeBuildInputs = kernel.moduleBuildDependencies ++ [ bc ];

  preBuild = ''
    makeFlagsArray+=("KVER=${kernel.modDirVersion}")
    makeFlagsArray+=("KSRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build")
  '';

  enableParallelBuilding = true;

  installPhase = ''
    mkdir -p ${modDestDir}
    find . -name '*.ko' -exec cp --parents '{}' ${modDestDir} \;
    find ${modDestDir} -name '*.ko' -exec xz -f '{}' \;
  '';

  meta = with lib; {
    description = "Realtek RTL8188CU driver";
    longDescription = ''
      A kernel module for Realtek 8188 network cards.
    '';
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
  };
}
