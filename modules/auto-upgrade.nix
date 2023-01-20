{ config, lib, ... }:
let
  hostName = config.networking.hostName;
in
{
  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = true;

  system.autoUpgrade.flake = "/etc/nixos/flake#${hostName}";
  #system.autoUpgrade.flake = "/etc/nixos/flake/hosts/${hostName}#${hostName}";  # doesn't have the `private` input
  system.autoUpgrade.flags = [
    "--override-input" "private" "path:/etc/nixos/hosts/${hostName}/private"
    # This would update the outer flake, which is not what we want:
    #"--update-input" "nixpkgs" "--commit-lock-file"
  ];

  systemd.services.nixos-upgrade.script = lib.mkBefore ''
    nix flake lock /etc/nixos/flake/hosts/${hostName} --update-input nixpkgs --commit-lock-file
  '';

  # https://github.com/NixOS/nixpkgs/issues/79109
  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 60d";
}
