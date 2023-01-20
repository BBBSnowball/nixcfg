{ pkgs, lib, ... }:
{
  # Use Pipewire for screensharing, e.g. with edumeet.
  # copied from https://github.com/thelegy/yaner/blob/9c73340703089af31c546e1c7eea2310765d1dce/machines/th1/default.nix#L79
  xdg.portal = {
    enable = true;
    #extraPortals = with pkgs; [ xdg-desktop-portal-wlr ];
    wlr.enable = true;
    #gtkUsePortal = true;  # see below
  };

  services.pipewire = {
    enable = true;
    pulse.enable = lib.mkDefault false;
  };

  users.users.user = {
    packages = with pkgs; [
      slurp grim
    ];
  };

  # NixOS has deprecated xdg.portal.gtkUsePortal but it works ok for me so let's keep the effect
  environment.sessionVariables.GTK_USE_PORTAL = "1";
}
