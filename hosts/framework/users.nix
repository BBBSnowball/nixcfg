{ pkgs, private, ... }:
let
  basicUser = {
    # generate contents with `mkpasswd -m sha-512`
    passwordFile = "/etc/nixos/secret/rootpw";

    openssh.authorizedKeys.keyFiles = [ "${private}/ssh-laptop.pub" ];
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
    extraGroups = [ "dialout" "wheel" ];
  };

  users.users.user2 = guiUser // {
    extraGroups = [ ];
  };
}

