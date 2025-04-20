{ pkgs ? import <nixpkgs> {}, frontend ? pkgs.lldap.frontend }:
let inherit (pkgs) lib; in
rec {
  # su user
  # nix-shell /etc/nixos/flake/hosts/nixosvm/containers/omas/lldap-static.nix -A shell --run lldap-static-info >/tmp/lldap-static-info.nix
  lldap-static-info = with pkgs; writeShellScriptBin "lldap-static-info" ''
    set -eo pipefail

    PATH=${lib.makeBinPath [yq htmlq gnused nix]}:"$PATH"
    src=${frontend.src}/app

    ${builtins.readFile ./lldap-static.sh}
  '';

  shell = pkgs.mkShell { packages = [ lldap-static-info ]; };

  lldap-static = let
    info = import ./lldap-static-info.nix { inherit (pkgs) fetchurl; };
    mklink = path: drv: "ln -s ${drv} $out/${path}";
    mklinks = lib.mapAttrsToList mklink info;
  in pkgs.runCommand "${frontend.name}-static" {} ''
    mkdir $out $out/fonts
    ${pkgs.lib.concatLines mklinks}
  '';

  frontend-static = pkgs.runCommand frontend.name {} ''
    cp -r ${frontend} $out
    chmod +w $out/*
    cp ${frontend.src}/app/index_local.html $out/index.html
    chmod -R u+w $out/static
    cp -TurL ${lldap-static} $out/static
  '';
}
