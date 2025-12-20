{ pkgs, ... }:
{
  nixpkgs.overlays = [
    (import ./brother_ql_pkg.nix { inherit pkgs; }).overlay
  ];

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


  # also make the brother-ql tool available for the user
  # I couldn't get the Brother QL-500 to work through cups and the
  # web interface can only do text so we have to access it directly.
  users.users.user = {
    extraGroups = [ "lp" ];
    packages = (with pkgs; [
      (python3Packages.brother-ql)
    ]);
  };
}
