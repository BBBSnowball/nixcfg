{ pkgs, config, privateForHost, secretForHost, nixpkgs-unstable, ... }:
let
  moreSecure = config.environment.moreSecure;

  basicUser = {
    # generate contents with `mkpasswd -m sha-512`
    hashedPasswordFile = if moreSecure
    then "${secretForHost}/rootpw2"
    else "${secretForHost}/rootpw";

    openssh.authorizedKeys.keyFiles = [ "${privateForHost}/ssh-laptop.pub" ];
  };
  rootUser = basicUser;
  guiUser = basicUser // {
    isNormalUser = true;

    packages = with pkgs; [
      x11vnc
      #vscode-fhs  # We need MS C++ Extension for PlatformIO.
      #nixpkgs-unstable.legacyPackages.x86_64-linux.vscode-fhs
      (import nixpkgs-unstable { system = pkgs.stdenv.hostPlatform.system; config = { allowUnfree = true; }; }).vscode
      python3 # for PlatformIO
      glasgow
    ];
  };
in
{
  users.users.root = rootUser;

  users.users.user = guiUser // {
    extraGroups = [ "dialout" "plugdev" "wheel" "wireshark" "lp" ];
  };

  users.users.user2 = guiUser // {
    extraGroups = [ "dialout" ];
  };

  users.users.user3 = guiUser // {
    extraGroups = [ "dialout" "dockerrootless" ];
    packages = with pkgs; [
      docker-compose
    ] ++ guiUser.packages;
  };

  users.users.user4 = guiUser // {
    extraGroups = [ "dialout" ];
  };

  users.users.gos = basicUser // {
    extraGroups = [ ];
    isNormalUser = true;

    packages = with pkgs; [
      # https://grapheneos.org/build#build-dependencies
      # -> use nix-shell, instead
      #gitRepo git gnupg
      #libgcc binutils
      #(python3.withPackages (p: with p; [ protobuf ]))
      #nodejs
      #yarn
      #gperf
      #pkgsi686Linux.gcc.libc_lib
      #pkgsi686Linux.gcc.libc_dev
      #pkgsi686Linux.gcc
      #signify
    ];
  };
}

