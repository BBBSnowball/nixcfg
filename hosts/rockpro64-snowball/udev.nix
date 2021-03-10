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
  '';
}
