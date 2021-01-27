{ config, pkgs, ... }:
{
  hardware.deviceTree.overlays = [ ./dt-overlay--use-fan.dts ];

  nixpkgs.overlays = [ (self: super: {
    deviceTree = super.deviceTree // { applyOverlays = (import ./applyOverlays.nix { inherit (self) stdenvNoCC dtc findutils lib; }).applyOverlays; };
  }) ];
}
