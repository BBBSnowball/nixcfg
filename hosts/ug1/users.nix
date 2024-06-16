{ lib, pkgs, config, privateForHost, secretForHost, nixpkgs-unstable, ... }:
let
  moreSecure = config.environment.moreSecure;

  basicUser = {
    # generate contents with `mkpasswd -m sha-512`
    hashedPasswordFile = "${secretForHost}/rootpw";

    openssh.authorizedKeys.keyFiles = [
      "${privateForHost}/ssh-laptop.pub"
      "${privateForHost}/ssh-user@fwa-for-ugreen.pub"
    ];
  };
  rootUser = basicUser;
  normalUser = basicUser // {
    isNormalUser = true;
  };
in
{
  users.mutableUsers = false;

  users.users.root = rootUser // {
  };

  users.users.user = normalUser // {
    extraGroups = [ "dialout" "plugdev" "wheel" "wireshark" ];
  };

  users.users.user2 = normalUser;
}

