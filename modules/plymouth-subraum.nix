{ pkgs, routeromen, ... }:
let
  theme = "subraum";
  inherit (pkgs.stdenv.hostPlatform) system;
  themePkg = routeromen.packages.${system}."plymouth-${theme}";
in
{
  config.boot.plymouth = {
    enable = true;
    themePackages = [ themePkg ];
    inherit theme;
  };
  config.boot.initrd.systemd.enable = true;
}
