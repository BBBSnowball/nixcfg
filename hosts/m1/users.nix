{ pkgs, private, secretForHost, ... }:
let
  basicUser = {
    # generate contents with `mkpasswd -m sha-512`
    passwordFile = "${secretForHost}/rootpw";

    openssh.authorizedKeys.keyFiles = [ "${private}/ssh-laptop.pub" ];
  };
  rootUser = basicUser;
  guiUser = basicUser // {
    isNormalUser = true;

    packages = with pkgs; [
      firefox pavucontrol chromium
      #mplayer mpv
      speedcrunch
      libreoffice gimp
      gnome.eog gnome.evince
      x11vnc
      vscode  # We need MS C++ Extension for PlatformIO.
      python3 # for PlatformIO
      w3m
      kupfer
      #(git.override { guiSupport = true; })
      gnome.gnome-screenshot
      gnome.gnome-tweaks
    ];
  };
in
{
  users.users.root = rootUser;

  users.users.user = guiUser // {
    extraGroups = [ "dialout" "plugdev" "wheel" "wireshark" ];
  };

  users.users.user2 = guiUser // {
    extraGroups = [ ];
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

