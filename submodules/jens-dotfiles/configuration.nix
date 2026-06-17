# This is the entry point for my NixOS configuration.
{ name, path, nixpkgs, isIso, extraLayersDir, flakeInputs, flakeOutputs, system, extraOverlays }:
{ lib, config, pkgs, ... }:

with lib;

let
  installResult = builtins.fromJSON (builtins.readFile (path + "/install-result.json"));
  dotfilesConfig = import (path + "/dotfiles.nix");
  layerPath = layerName: let
    filePath = ./layers + "/${layerName}.nix";
    dirPath = ./layers + "/${layerName}";
    extraDirFilePath = extraLayersDir + "/${layerName}.nix";
    extraDirDirPath = extraLayersDir + "/${layerName}";
  in
  if builtins.pathExists filePath
    then filePath
    else if builtins.pathExists dirPath
      then dirPath
      else if builtins.pathExists extraDirFilePath
        then extraDirFilePath
        else if builtins.pathExists extraDirDirPath
          then extraDirDirPath
          else builtins.throw "Cannot find layer `${layerName}`";

  layerImports = map layerPath dotfilesConfig.layers;

  normalSystemConfiguration = (lib.attrsets.optionalAttrs (!isIso) {
    # TODO move to machine configuration?
    imports = [ (path + "/hardware-configuration.nix") ];
    # Bootloader
    boot.loader.systemd-boot.enable = (installResult.bootloader == "efi");
    boot.loader.efi.canTouchEfiVariables = (installResult.bootloader == "efi");
    boot.loader.grub.enable = (installResult.bootloader == "bios");
    boot.loader.grub.device = installResult.installedBlockDevice;

    boot.initrd.luks.devices = if installResult.luks then {
      cryptvol = {
        device = "/dev/disk/by-uuid/" + installResult.luksPartitionUuid;
        allowDiscards = true;
      };
    } else {};
  });
in
{
  imports = [
    ./modules
    (path + "/configuration.nix")
    normalSystemConfiguration
    flakeInputs.homemanager.nixosModules.home-manager
    flakeInputs.matrix-homeserver.nixosModules.matrix-homeserver
  ] ++ layerImports;

  home-manager = {
    useGlobalPkgs = true;
    # disable home-managers usage of nix-env
    useUserPackages = true;
  };

  _module.args.isIso = lib.mkDefault false;

  nixpkgs.overlays = [
    (import ./pkgs)
    #flakeInputs.q.overlay
    (self: super: {
      q = flakeInputs.q.packages.${system}.q;
      #q = if system == "aarch64-multiplatform"
      #  then flakeInputs.q.packages.x86_64-linux.aarch64-multiplatform.q;
      #  else flakeInputs.q.packages.${system}.q;
    })
  ] ++ extraOverlays;

  # Pin nixpkgs in nix path
  nix.nixPath = [ "nixpkgs=${nixpkgs}" ];
  nix.registry.nixpkgs.flake = nixpkgs;
  # Make nixpkgs path available inside of the configuration
  #_module.args.nixpkgsPath = nixpkgs;

  # Let 'nixos-version --json' know about the Git revision
  # of this flake.
  system.configurationRevision = lib.mkIf (flakeInputs.self ? rev) flakeInputs.self.rev;

  environment.shellAliases = {
    # nixos-option won't run without a configuration. With an empty config it does not show configured values, but can at least be used to search options and show default values.
    nixos-option = "nixos-option -I nixos-config=${pkgs.writeText "empty-configuration.nix" "{...}:{}"}";
  };

  # Default hostname ist machine directory name
  networking.hostName = lib.mkDefault name;

  queezle.qnet =
    let
      qnetFile = path + "/qnet.json";
      exists = builtins.pathExists qnetFile;
      qnet = if exists then builtins.fromJSON (builtins.readFile qnetFile) else null;
    in if exists then {
      enable = mkDefault true;
      address = mkDefault qnet.address;
      allowedIPs = mkDefault qnet.allowedIPs;
      peerEndpoint = mkDefault qnet.peerEndpoint;
      publicKey = mkDefault qnet.publicKey;
    } else {};
}
