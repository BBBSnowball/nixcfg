{ config, pkgs, lib, ... }:
let
  test = config.services.matrix-synapse.isTestInstance;
  testSuffix = if test then "-test" else "";
  name = "mautrix-telegram${testSuffix}";

  pythonWithPkgs = import ./requirements.nix { inherit pkgs; };
  mautrixTelegram = pkgs.callPackage ./mautrix-telegram-pkg.nix { inherit pythonWithPkgs; };
  python = pythonWithPkgs.interpreterWithPackages (_: [ mautrixTelegram pythonWithPkgs.packages.alembic ]);
  configPatches = [
    /etc/nixos/c3pb/mautrix-telegram/config-public.patch
    /etc/nixos/secret/mautrix-telegram/config-secret.patch
  ] ++ (if test then [
    /etc/nixos/secret/mautrix-telegram/config-test.patch
  ] else []);
  makeConfig = pkgs.writeShellScript "mautrix-telegram-config" ''
    set -e
    umask 077
    chmod 700 .
    cp ${mautrixTelegram}/example-config.yaml config.yaml
    for p in ${toString configPatches} ; do
      ${pkgs.patch}/bin/patch -p0 <$p
    done
    chown mautrix-telegram-test config.yaml
  '';
  initScript = pkgs.writeShellScript "mautrix-telegram-init" ''
    set -e
    umask 077
    if ! [ -e registration.yaml ] ; then
      cp config.yaml config-registration.yaml
      chmod u+w config-registration.yaml
      ${python}/bin/python -m mautrix_telegram -g -c config-registration.yaml
    fi

    ln -sfn ${mautrixTelegram}/alembic.ini alembic.ini
    ln -sfn ${mautrixTelegram}/alembic alembic
    ${python}/bin/alembic upgrade head
  '';
in {
  users.users."${name}" = {
    isNormalUser = false;
    home = "/var/lib/${name}";
  };

  systemd.services."${name}" = {
    after = ["network.target" "matrix-synapse.service"];
    description = "Matrix-to-Telegram Bridge";
    serviceConfig = {
      Type = "simple";
      ExecStartPre = [
        "+${pkgs.bash}/bin/bash ${makeConfig}"
        "${pkgs.bash}/bin/bash ${initScript}"
      ];
      ExecStart = "${python}/bin/python -m mautrix_telegram";
      WorkingDirectory = "/var/lib/${name}";
      StateDirectory = "${name}";
      User = "${name}";
      Restart = "on-failure";
      RestartSec = 10;
    };
    restartTriggers = configPatches ++ [ initScript ];
  };
}
