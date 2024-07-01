{ lib, pkgs, config, privateForHost, secretForHost, nixpkgs-unstable, ... }:
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
  guiUserTrusted = guiUser true;
  guiUserUntrusted = guiUser false;
in
{
  users.users.root = rootUser;

  users.users.user = guiUserTrusted // {
    extraGroups = [ "dialout" "plugdev" "wheel" "wireshark" ];
  };

  users.users.user2 = lib.mkMerge [ guiUserUntrusted {
    extraGroups = [ "dialout" ];
    packages = with pkgs; [
      ghidra
    ];
  } ];

  users.users.snotes = let x = guiUserUntrusted; in x // {
    packages = with pkgs; x.packages ++ [
      pass
    ];
  };

  # We don't use services.passSecretService.enable because that would enable the
  # service for all users.
  # see https://github.com/mdellweg/pass_secret_service/tree/develop/systemd
  systemd.user.services."dbus-org.freedesktop.secrets" = {
    description = "Expose the libsecret dbus api with pass as backend";
    unitConfig.ConditionUser = "snotes";
    serviceConfig = {
      BusName = "org.freedesktop.secrets";
      ExecStart = "${pkgs.pass-secret-service}/bin/pass_secret_service";
    };
  };
  services.dbus.packages = [ pkgs.pass-secret-service ];

  virtualisation.docker.rootless.enable = true;
  systemd.user.services.docker.unitConfig.ConditionUser = lib.mkForce "snotes";
}

