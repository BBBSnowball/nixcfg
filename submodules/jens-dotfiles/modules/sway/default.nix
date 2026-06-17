inputs@{ lib, pkgs, config, ... }:

with lib;
let
  cfg = config.queezle.sway;
in
{
  options = {
    queezle.sway = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
      user = mkOption {
        type = types.str;
        default = "jens";
      };
      autoLockBeforeSuspend = mkOption {
        type = types.bool;
        default = true;
      };
      wallpaper = mkOption {
        type = types.path;
        default = pkgs.requireFile rec {
          name = "background.png";
          url = "'undefined'";
          sha256 = "9df437c4ba4dc845e10f57e1bbbbee6a4139329f36dbdd92c98a8fb0b45b1c22";
        };
      };
      lockscreen = mkOption {
        type = types.path;
        default = pkgs.requireFile rec {
          name = "retrowave.png";
          url = "'undefined'";
          sha256 = "b41a116c40cc294b6367fa4828110321156addb1d41e072fbd80cdf8748b35c3";
        };
      };
    };

  };
  config = mkIf cfg.enable {
    queezle.terminal.enable = true;
    queezle.desktop.launcher.enable = true;
    queezle.desktop.launcher.dmenu = true;

    home-manager.users."${cfg.user}".xdg.configFile."sway/config" = {
      source = import ./config.nix inputs;
    };
  };
}
