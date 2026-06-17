{ pkgs, ... }:

{
  users.users.audio = {
    isNormalUser = true;
    uid = 1102;
    extraGroups = [ "pulse-access" "audio" ];
    packages = with pkgs; [
      ardour
      calf
      #vcv-rack
      #sunvox
    ];
  };
}
