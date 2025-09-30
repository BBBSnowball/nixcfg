{ lib, pkgs, ... }:
{
  # see https://nixos.wiki/wiki/AMD_GPU
  boot.initrd.kernelModules = [ "amdgpu" ];
  services.xserver.videoDrivers = [ "amdgpu" ];
  systemd.tmpfiles.rules = [
    "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
  ];

  hardware.graphics.extraPackages = with pkgs; [
    rocmPackages.clr.icd
  ];

  hardware.amdgpu.opencl.enable = true;
  hardware.amdgpu.amdvlk.enable = true;

  #services.lact.enable = true;
  environment.systemPackages = with pkgs; [ lact ];
  systemd.packages = with pkgs; [ lact ];
  systemd.services.lactd.wantedBy = ["multi-user.target"];

  # use newest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;


  # add some benchmarks and other tools
  users.users.user.packages = with pkgs; [
    unigine-superposition
  ];
  nixpkgs.allowUnfreeByName = [
    "unigine-superposition"
  ];
}
