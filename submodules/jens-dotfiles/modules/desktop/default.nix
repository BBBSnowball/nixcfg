inputs@{ lib, pkgs, config, ... }:

with lib;
let
  cfg = config.queezle.desktop;
  squeekboardConfig = import ./config/squeekboard.nix inputs;
in
{
  options = {
    queezle.desktop = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
      user = mkOption {
        type = types.str;
        default = "jens";
      };
    };
  };
  config = mkIf cfg.enable {
    queezle.terminal.enable = true;

    home-manager.users."${cfg.user}".xdg = {
      configFile."foot/foot.ini" = {
        source = import ./config/foot.nix inputs;
      };
      dataFile."squeekboard/keyboards/terminal/us.yaml" = { source = squeekboardConfig; };
      dataFile."squeekboard/keyboards/terminal/us_wide.yaml" = { source = squeekboardConfig; };
      dataFile."squeekboard/keyboards/us.yaml" = { source = squeekboardConfig; };
      dataFile."squeekboard/keyboards/us_wide.yaml" = { source = squeekboardConfig; };

      # TODO: remove after next nixpkgs-pinephone update
      dataFile."squeekboard/keyboards/terminal.yaml" = { source = squeekboardConfig; };
      dataFile."squeekboard/keyboards/terminal_wide.yaml" = { source = squeekboardConfig; };
    };
  };
}
