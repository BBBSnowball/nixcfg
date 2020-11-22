{ config, pkgs, ... }:
{
  # enables usb-modeswitch, also useful for USB WiFi adapter that enumerates as CDROM, by default
  hardware.usbWwan.enable = true;

  nixpkgs.overlays = [ (import ./switch-E3531-to-tty.nix) ];

  services.udev.extraRules = ''
    # If you are using a different USB adapter, you must update idVendor and idProduct but also the interface number.
    # There is usually more than one ttyUSB. You need one for the modem and one for SMS and both of them must respond
    # to AT commands. You can test this by opening the port with picocom or `smsd -C` and sending "AT\n". The reply
    # should be "OK".

    # I had no luck with ATTRS{bInterfaceNumber} so we are using ENV{ID_USB_INTERFACE_NUM}.
    # see https://stackoverflow.com/questions/19174482/udev-rule-with-binterfacenumber-doesnt-work

    # We are telling ModemManager to leave this port alone and we are telling systemd to start smsd. We also create a
    # symlink. This is useful for debugging.
    ATTRS{idVendor}=="12d1", ATTRS{idProduct}=="1001", ENV{ID_USB_INTERFACE_NUM}=="02", \
      ENV{ID_MM_PORT_IGNORE}="1", \
      GROUP="smsd", ENV{SMSD}="1", TAG+="systemd", ENV{SYSTEMD_WANTS}="smsd@", GROUP="smsd", MODE="0660", SYMLINK="ttySMS"

    #NOTE ModemManager seems to expect that it can access certain functions without the pin and it doesn't even
    #     try to supply the pin in that case. There error message in syslog is "couldn't load IMSI: 'SIM PIN required'".
    #     Therefore, I have disabled the pin for my SIM card. You can do it by sending this to the tty:
    #     AT+CPIN?
    #     AT+CLCK="SC",0,"<PIN>"
    #     AT+CPIN?
    #     FIXME untested ^^
    #     You should probably prefer: mmcli --list-modems; mmcli --sim=x --pin=xxxx --disable-pin
  '';

  users.groups.smsd = {};

  systemd.services."smsd@" = {
    #FIXME real service
    serviceConfig.Type = "oneshot";
    script = ''echo blub,$INSTANCE'';
    environment.INSTANCE = "%I";
  };
}
