{ pkgs, ... }:
{
  users.users.user.packages = with pkgs; [
    vscode  # We need MS C++ Extension for PlatformIO.
    openocd gdb
  ];
 
  services.udev.extraRules = ''
    # ST-Link/V2
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="3748", GROUP="dialout"
  '';
}
