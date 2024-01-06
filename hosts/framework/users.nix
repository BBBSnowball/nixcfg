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
      firefox pavucontrol chromium
      mplayer mpv
      speedcrunch
      libreoffice gimp
      gnome.eog gnome.evince
      x11vnc
      #vscode-fhs  # We need MS C++ Extension for PlatformIO.
      #nixpkgs-unstable.legacyPackages.x86_64-linux.vscode-fhs
      (import nixpkgs-unstable { system = pkgs.stdenv.hostPlatform.system; config = { allowUnfree = true; }; }).vscode
      python3 # for PlatformIO
      w3m
      kupfer
      #(git.override { guiSupport = true; })
      gnome.gnome-screenshot
      gnome.gnome-tweaks
      gnome.nautilus
      git-annex
    ];
  };
in
{
  users.users.root = rootUser;

  users.users.user = guiUser // {
    extraGroups = [ "dialout" "plugdev" "wheel" "wireshark" ];
  };

  users.users.user2 = guiUser // {
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

