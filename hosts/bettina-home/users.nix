{ pkgs, config, privateForHost, secretForHost, nixpkgs-unstable, ... }:
let
  basicUser = {
    # generate contents with `mkpasswd -m sha-512`
    hashedPasswordFile = "${secretForHost}/rootpw";

    openssh.authorizedKeys.keyFiles = [
      "${privateForHost}/ssh-laptop.pub"
      "${privateForHost}/ssh-fw.pub"
    ];
  };
  rootUser = basicUser;
  guiUser = basicUser // {
    isNormalUser = true;

    packages = with pkgs; [
      firefox pavucontrol
      kupfer
      git-annex
    ];
  };
in
{
  users.users.root = rootUser;

  users.users.user = guiUser // {
    extraGroups = [ "dialout" "plugdev" "wheel" "wireshark" ];
  };
}

