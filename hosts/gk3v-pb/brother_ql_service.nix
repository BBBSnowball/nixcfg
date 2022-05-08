{ pkgs, ... }:
{
  nixpkgs.overlays = [ (import ./brother_ql.nix { inherit pkgs; }).overlay ];

  users.users.brother-ql = {
    isSystemUser = true;
    extraGroups = [ "lp" ];
  };
  users.users.brother-ql.group = "brother-ql";
  users.groups.brother-ql = {};

  systemd.services.brother-ql = {
    serviceConfig.User = "brother-ql";
    script = ''
      ${pkgs.python3Packages.brother-ql-web}/bin/brother_ql_web usb://0x04f9:0x2015
    '';
  };

  networking.firewall.allowedTCPPorts = [ 8013 ];
}
