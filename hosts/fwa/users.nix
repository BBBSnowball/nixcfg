{ pkgs, config, privateForHost, secretForHost, nixpkgs-unstable, ... }:
let
  moreSecure = config.environment.moreSecure;

  basicUser = {
    # generate contents with `mkpasswd -m sha-512`
    hashedPasswordFile = "${secretForHost}/rootpw";

    openssh.authorizedKeys.keyFiles = [ "${privateForHost}/ssh-laptop-fwa.pub" ];
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
}

