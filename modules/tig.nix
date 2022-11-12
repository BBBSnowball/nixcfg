{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.tig;
in
  
{
  options.programs.tig = {
    enable = mkEnableOption "tig";

    package = mkOption {
      type = types.package;
      default = pkgs.tig-unwrapped;
      defaultText = literalExpression "pkgs.tig-unwrapped";
      description = "The tig package to use";
    };

    configText = mkOption {
      type = types.lines;
      example = "bind status A !git commit --amend";
      description = "Configuration for tigrc. See tigrc(5).";
    };

    addToSystemPackages = mkOption {
      type = types.bool;
      default = true;
      description = "Add tig to environment.systemPackages.";
    };
  };

  config = mkIf cfg.enable {
    nixpkgs.overlays = [ (self: super: {
      tig-unwrapped = super.tig;
      tig = self.writeShellScriptBin "tig" ''
        export TIGRC_SYSTEM=/etc/tigrc
        exec ${cfg.package}/bin/tig "$@"
      '';
    }) ];

    programs.tig.configText = mkBefore ''
      source ${pkgs.tig-unwrapped}/etc/tigrc
    '';

    environment.etc."tigrc".text = cfg.configText;

    environment.systemPackages = mkIf cfg.addToSystemPackages [ pkgs.tig ];
  };
}
