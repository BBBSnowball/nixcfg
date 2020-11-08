{ stdenv, lib, fetchFromGitHub, kernel, bc }:


let modDestDir = "$out/lib/modules/${kernel.modDirVersion}/kernel/drivers/net/wireless/realtek/rtl8188gu";

in stdenv.mkDerivation rec {
  name = "r8188gu-${kernel.version}-${version}";
  # on update please verify that the source matches the realtek version
  version = "1.0";

  src = fetchFromGitHub {
    owner = "McMCCRU";
    repo = "rtl8188gu";
    rev = "ed82c194bd5e0b3c068ca665a3c4de8f31041e35";
    sha256 = "sha256-9iUWAbGYhpiUIST+4g1Lj6gYeIWgQpHKbPP9kiqooko=";
  };

  hardeningDisable = [ "pic" ];

  nativeBuildInputs = kernel.moduleBuildDependencies ++ [ bc ];

  preBuild = ''
    makeFlagsArray+=("KVER=${kernel.modDirVersion}")
    makeFlagsArray+=("KSRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build")
    makeFlagsArray+=("modules")

    # try to make it work for v5.8 - but update_mgmt_frame_registrations is too different
    #find -type f -exec sed -i 's/sha256_/rtl_sha256_/g ; s/timespec/timespec64/ ; s/getboottime/getboottime64/ ; s/mgmt_frame_register/update_mgmt_frame_registrations/g' {} \+
    find -type f -exec sed -i 's/timespec/timespec64/ ; s/getboottime/getboottime64/ ; s/entry = proc_create_data.*/entry = NULL;/' {} \+
  '';

  enableParallelBuilding = true;

  installPhase = ''
    mkdir -p ${modDestDir}
    find . -name '*.ko' -exec cp --parents '{}' ${modDestDir} \;
    find ${modDestDir} -name '*.ko' -exec xz -f '{}' \;
  '';

  meta = with lib; {
    description = "Realtek RTL8188GU driver";
    longDescription = ''
      A kernel module for Realtek 8188 network cards.
    '';
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
  };
}
