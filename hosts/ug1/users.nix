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
  
  users.users.xps-qubes = normalUser // {
    openssh.authorizedKeys.keyFiles = [
      "${privateForHost}/ssh-qubes-netvm.pub"
    ];
    #group = "sftponly";
  };
  users.users.framework13 = normalUser // {
    openssh.authorizedKeys.keyFiles = [
      "${privateForHost}/ssh-framework13.pub"
    ];
    #group = "sftponly";
  };
  users.groups.sftponly = {};
  # https://serverfault.com/a/354618
  services.openssh.extraConfig = ''
    Match group sftponly
     ChrootDirectory /media/data/backup/%u
     X11Forwarding no
     AllowTcpForwarding no
     AllowAgentForwarding no
     ForceCommand internal-sftp -d /%u
  '';
}

