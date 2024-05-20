{ pkgs, config, privateForHost, secretForHost, nixpkgs-unstable, ... }:
let
  moreSecure = config.environment.moreSecure;

  basicUser = {
    # generate contents with `mkpasswd -m sha-512`
    hashedPasswordFile = "${secretForHost}/rootpw";

    openssh.authorizedKeys.keyFiles = [ "${privateForHost}/ssh-laptop-fwa.pub" ];
  };
  rootUser = basicUser;
  guiUser = trusted:
  basicUser // {
    isNormalUser = true;

    packages = let
      system = pkgs.stdenv.hostPlatform.system;
      pkgsUnstable = nixpkgs-unstable.legacyPackages.${system};
      pkgsUnstableUnfree = import nixpkgs-unstable { inherit system; config.allowUnfree = true; };
    in with pkgs; [
      x11vnc
      python3 # for PlatformIO but also useful in general
    ] ++ (if trusted then [
      pkgsUnstable.vscodium-fhs
    ] else [
      #vscode-fhs  # We need MS C++ Extension for PlatformIO.
      pkgsUnstableUnfree.vscode
    ]);
  };
in
{
  users.users.root = rootUser;

  users.users.user = guiUser true // {
    extraGroups = [ "dialout" "plugdev" "wheel" "wireshark" ];
  };

  users.users.user2 = guiUser false // {
    extraGroups = [ "dialout" ];
  };
}

