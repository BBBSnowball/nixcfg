{ config, pkgs, ... }:
{
  hardware.deviceTree.overlays = let
    compileOverlay = input: pkgs.runCommand "dtbo" { inherit input; inherit (pkgs) dtc; } ''
      $dtc/bin/dtc -I dts -O dtb -o $out $input
    '';
  in [ ./dt-overlay--use-fan.dts (compileOverlay ./dt-overlay--use-fan.dts) ];

  nixpkgs.overlays = [ (self: super: {
    deviceTree = super.deviceTree // { applyOverlays = (import ./applyOverlays.nix { inherit (self) stdenvNoCC dtc findutils lib; }).applyOverlays; };
  }) ];
}
