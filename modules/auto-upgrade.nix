{
  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = true;

  # https://github.com/NixOS/nixpkgs/issues/79109
  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 60d";
}
