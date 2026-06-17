{ lib, pkgs, config, ... }:

with lib;
let
  cfg = config.queezle.desktop.launcher;
  launcher = pkgs.writeScriptBin "launcher" ''
    ${pkgs.fuzzel}/bin/fuzzel \
      --dpi-aware no \
      --terminal terminal \
      --border-radius 0 \
      --background 111111e6 \
      --text-color ccccccff \
      --match-color dd5001ff \
      --selection-color 000000e6 \
      --vertical-pad 20 \
      --font 'monospace:size=12' \
      --width 100 \
      --lines 25
  '';
  dmenu = pkgs.writeScriptBin "dmenu" ''
    ${pkgs.fuzzel}/bin/fuzzel \
      --dmenu \
      --dpi-aware no \
      --border-radius 0 \
      --background 111111e6 \
      --text-color ccccccff \
      --match-color dd5001ff \
      --selection-color 000000e6 \
      --vertical-pad 20 \
      --font 'monospace:size=12' \
      --width 100 \
      --lines 25
  '';
in
{
  options = {
    queezle.desktop.launcher = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
      dmenu = mkOption {
        type = types.bool;
        default = false;
      };
    };
  };
  config = mkIf cfg.enable {
    # 'terminal' launcher script enables desktop entries that rely on terminal support, e.g. htop
    queezle.terminal.enable = true;
    environment.systemPackages = [ launcher pkgs.fuzzel ] ++ optionals cfg.dmenu [ dmenu ];
  };
}
