{ lib, pkgs, config, ... }:
let
  hostName = config.networking.hostName;

  notify = (config.programs.sendmail-to-smarthost.enable or false)
    && (config.programs.sendmail-to-smarthost.enableNotifyService or false);
in
{
  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = true;

  system.autoUpgrade.flake = "/etc/nixos/flake#${hostName}";
  #system.autoUpgrade.flake = "/etc/nixos/flake/hosts/${hostName}#${hostName}";  # doesn't have the `private` input

  # use exactly these flags, no `--refresh` or `--upgrade` because we do the update in a separate step (see below)
  system.autoUpgrade.upgrade = false;
  system.autoUpgrade.flags = lib.mkForce [
    # add flake argument because mkForce drops default arguments
    "--flake" config.system.autoUpgrade.flake

    "--override-input" "private" "path:/etc/nixos/hosts/${hostName}/private/private/"
    # This would update the outer flake, which is not what we want:
    #"--update-input" "nixpkgs" "--commit-lock-file"
  ];

  systemd.services.nixos-upgrade.script = lib.mkBefore ''
    nix flake update nixpkgs --flake /etc/nixos/flake/hosts/${hostName} --commit-lock-file
  '';
  systemd.services.nixos-upgrade.path = [ pkgs.gnupg ];  # might be needed for commit

  # https://github.com/NixOS/nixpkgs/issues/79109
  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 60d";


  systemd.services.nixos-upgrade.unitConfig.OnFailure = lib.mkIf notify "notify-by-mail@%n";
}
