{
  services.udev.extraRules = ''
    # This matches any Prolific 2303 because this one doesn't have any serial number or other distinguishing feature.
    ACTION=="add", SUBSYSTEM=="tty", SUBSYSTEMS=="usb", ATTRS{idVendor}=="067b", ATTRS{idProduct}=="2303", GROUP="dialout", SYMLINK+="ttyUSB-pi0", ENV{ID_MM_DEVICE_IGNORE}="1"

    # This is also for a generic FT2232H/FT4232H.
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0403", ATTR{idProduct}=="601[01]", GROUP="dialout", MODE="0660", ENV{ID_MM_DEVICE_IGNORE}="1"
    # https://www.florian-wolters.de/blog/2016/11/02/udev-rules-for-quad-serial-adapter-ft-4232h/
    ACTION=="add", SUBSYSTEMS=="usb", ENV{.LOCAL_ifNum}="$attr{bInterfaceNumber}"
    ACTION=="add", SUBSYSTEMS=="usb", KERNEL=="ttyUSB*", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6011", ENV{.LOCAL_ifNum}=="00", SYMLINK+="ttyUSB-FT4a"
    ACTION=="add", SUBSYSTEMS=="usb", KERNEL=="ttyUSB*", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6011", ENV{.LOCAL_ifNum}=="01", SYMLINK+="ttyUSB-FT4b"
    ACTION=="add", SUBSYSTEMS=="usb", KERNEL=="ttyUSB*", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6011", ENV{.LOCAL_ifNum}=="02", SYMLINK+="ttyUSB-FT4c"
    ACTION=="add", SUBSYSTEMS=="usb", KERNEL=="ttyUSB*", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6011", ENV{.LOCAL_ifNum}=="03", SYMLINK+="ttyUSB-FT4d"
    ACTION=="add", SUBSYSTEMS=="usb", KERNEL=="ttyUSB*", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6010", ENV{.LOCAL_ifNum}=="00", SYMLINK+="ttyUSB-FT2a", SYMLINK+="ttyUSB-GD32VF-jtag"
    ACTION=="add", SUBSYSTEMS=="usb", KERNEL=="ttyUSB*", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6010", ENV{.LOCAL_ifNum}=="01", SYMLINK+="ttyUSB-FT2b", SYMLINK+="ttyUSB-GD32VF-serial"

    # ESP32-C3
    ACTION=="add", SUBSYSTEMS=="usb", KERNEL=="ttyACM*", ATTRS{idVendor}=="303a", ATTRS{idProduct}=="1001", SYMLINK+="ttyACM-ESP", SYMLINK+="ttyUSB-GD32VF-serial"

    # Pixel 5, fastboot
    ACTION=="add", SUBSYSTEMS=="usb", ATTRS{idVendor}=="18d1", ATTRS{idProduct}=="4ee0", GROUP="flash-android", MODE="0660"
    # Pixel 5, adb
    ACTION=="add", SUBSYSTEMS=="usb", ATTRS{idVendor}=="18d1", ATTRS{idProduct}=="4ee7", GROUP="flash-android", MODE="0660"
  '';

  users.groups.flash-android = {};
  users.users.user.extraGroups = [ "flash-android" ];
}
