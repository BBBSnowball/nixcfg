{ lib, pkgs, config, ... }:

with lib;
let
  terminal = pkgs.writeScriptBin "terminal" ''
    PROMPT_NO_INITIAL_NEWLINE=1 ${config.queezle.terminal.executable} "$@"
  '';
  terminal2 = pkgs.writeScriptBin "terminal2" ''
    PROMPT_NO_INITIAL_NEWLINE=1 ${config.queezle.terminal.alt.executable} "$@"
  '';
in
{
  options = {
    queezle.terminal.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Install a 'terminal' and 'terminal2' wrapper script that launches the configured terminal emulator.";
    };

    queezle.terminal.executable = mkOption {
      type = types.path;
      default = "${pkgs.foot}/bin/footclient";
    };

    queezle.terminal.alt.executable = mkOption {
      type = types.path;
      default = if config.queezle.terminal.forceSoftwareRenderer then "${pkgs.foot}/bin/foot" else "${pkgs.kitty}/bin/kitty";
    };

    queezle.terminal.forceSoftwareRenderer = mkOption {
      type = types.bool;
      default = false;
    };
  };
  config = mkIf config.queezle.terminal.enable {
    environment.systemPackages = [
      terminal
      terminal2
      pkgs.foot
    ] ++ optional (!config.queezle.terminal.forceSoftwareRenderer) pkgs.kitty;
  };
}
