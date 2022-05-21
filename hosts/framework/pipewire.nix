{ pkgs, ... }:
{
  # Use Pipewire for screensharing, e.g. with edumeet.
  # copied from https://github.com/thelegy/yaner/blob/9c73340703089af31c546e1c7eea2310765d1dce/machines/th1/default.nix#L79
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-wlr ];
    #gtkUsePortal = true;
  };

  services.pipewire = {
    enable = true;
    pulse.enable = false;
  };

  users.users.user = {
    packages = with pkgs; [
      slurp grim
    ];
  };
}
