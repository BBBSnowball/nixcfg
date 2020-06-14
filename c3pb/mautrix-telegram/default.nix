{ config, pkgs, lib, ... }:
let
  test = true;
  testSuffix = if test then "-test" else "";

  pythonWithPkgs = import ./requirements.nix { inherit pkgs; };
  mautrixTelegram = pkgs.callPackage ./mautrix-telegram-pkg.nix { inherit pythonWithPkgs; };
  configPatches = [
    /etc/nixos/c3pb/mautrix-telegram/config-public.patch
    /etc/nixos/secret/mautrix-telegram/config-private.patch
    /etc/nixos/secret/mautrix-telegram/config-test.patch
  ];
  makeConfig = pkgs.writeShellScript "make-mautrix-telegram-config" ''
    cp ${mautrixTelegram}/example-config.yaml config.yaml
    for p in ${toString configPatches} ; do
      patch -p0 $p
    done
  '';
in {
  #FIXME remove
  environment.etc.blub.text = "${mautrixTelegram}";

  users.users."matrix-synapse${testSuffix}" = {
    isNormalUser = false;
    home = "/var/lib/mautrix-telegram${testSuffix}";
  };

  systemd.services."mautrix-telegram${testSuffix}" = {
    after = ["network.target" "matrix-synapse.service"];
    description = "Matrix-to-Telegram Bridge";
    serviceConfig = {
      Type = "simple";
      ExecStartPre = "+${pkgs.bash}/bin/bash ${makeConfig}";
      ExecStart = "/bin/bash -c \"source ./bin/activate && exec python -m mautrix_telegram\"";  #FIXME !!!!
      WorkingDirectory = "/var/lib/mautrix-telegram${testSuffix}";
      StateDirectory = "matrix-telegram${testSuffix}";
      User = "mautrix-telegram${testSuffix}";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };
}
