{ config, pkgs, lib, ... }:
let
  pythonWithPkgs = import ./requirements.nix { inherit pkgs; };
  mautrixTelegram = pkgs.callPackage ./mautrix-telegram-pkg.nix { inherit pythonWithPkgs; };
  configPatches = [/etc/nixos/c3pb/mautrix-telegram/config-public.patch /etc/nixos/secret/mautrix-telegram/config-private.patch];
  makeConfig = pkgs.writeShellScript "make-mautrix-telegram-config" ''
    cp ${mautrixTelegram}/example-config.yaml config.yaml
    for p in ${toString configPatches} ; do
      patch -p0 $p
    done
  '';
in {
  environment.etc.blub.text = "${mautrixTelegram}";

  systemd.services.mautrix-telegram = {
    after = ["network.target" "matrix-synapse.service"];
    description = "Matrix-to-Telegram Bridge";
    serviceConfig = {
      Type = "simple";
      ExecStartPre = "+${pkgs.bash}/bin/bash ${makeConfig}";
      ExecStart = "/bin/bash -c \"source ./bin/activate && exec python -m mautrix_telegram\"";
      WorkingDirectory = "/var/lib/mautrix-telegram";
      StateDirectory = "matrix-telegram";
      User = "mautrix-telegram";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };
}
