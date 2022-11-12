{
  services.udev.extraRules = ''
    # PureThermal 3 (but most likely the same for other PureThermal boards)
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1e4e", ATTR{idProduct}=="0100", GROUP="dialout", SYMLINK+="flir"
    # Bootloader
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="df11", GROUP="dialout"
  '';
}
