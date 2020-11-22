{ config, pkgs, ... }:
let
  pinfile = "/etc/nixos/secret/sim-pin";
in
{
  # enables usb-modeswitch, also useful for USB WiFi adapter that enumerates as CDROM, by default
  hardware.usbWwan.enable = true;

  nixpkgs.overlays = [
    (import ./switch-E3531-to-tty.nix)
    (self: super: {
      libmm = import ./libmm.nix {};
      smstools = import ./smstools.nix {};
    })
  ];

  services.udev.extraRules = ''
    # If you are using a different USB adapter, you must update idVendor and idProduct but also the interface number.
    # There is usually more than one ttyUSB. You need one for the modem and one for SMS and both of them must respond
    # to AT commands. You can test this by opening the port with picocom or `smsd -C` and sending "AT\n". The reply
    # should be "OK".
    # For E3531, port 1 is not an AT but port 0 and 2 are.

    # I had no luck with ATTRS{bInterfaceNumber} so we are using ENV{ID_USB_INTERFACE_NUM}.
    # see https://stackoverflow.com/questions/19174482/udev-rule-with-binterfacenumber-doesnt-work

    # We are telling ModemManager to leave this port alone and we are telling systemd to start smsd. We also create a
    # symlink. This is useful for debugging.
    ATTRS{idVendor}=="12d1", ATTRS{idProduct}=="1001", ENV{ID_USB_INTERFACE_NUM}=="02", \
      ENV{ID_MM_PORT_IGNORE}="1", \
      GROUP="smsd", ENV{SMSD}="1", TAG+="systemd", ENV{SYSTEMD_WANTS}="smsd@", GROUP="smsd", MODE="0660", SYMLINK="ttySMS"
  '';

  environment.etc."smsd.conf".text = ''
    devices = GSM1
    loglevel = 7
    
    # Settings to run smsd without root priviledges:
    user = smsd
    group = smsd

    #logfile = /var/log/sms/smsd.log
    # log to stdout
    logfile = 1

    outgoing = /var/lib/sms/outgoing
    checked  = /var/lib/sms/checked
    failed   = /var/lib/sms/failed
    incoming = /var/lib/sms/incoming
    report   = /var/lib/sms/report
    sent     = /var/lib/sms/sent
    infofile = /run/sms/smsd.running
    pidfile  = /run/sms/smsd.pid
    
    [GSM1]
    device = /dev/ttySMS
    incoming = yes
    pinsleeptime = 5
  '';

  users.users.smsd = {};
  users.groups.smsd = {};

  systemd.services."smsd@" = {
    serviceConfig = {
      Type = "simple";

      PermissionsStartOnly = true;
      User  = "smsd";
      Group = "smsd";

      RuntimeDirectory = "sms";
      StateDirectory   = "sms";
      #LogsDirectory    = "sms";

      # Config in runtime dir contains the pin but it is created with more
      # restricted mode. Logs might also contain the pin. The state dir
      # is group writable because it contains the spool directories.
      #FIXME If logs do contain secrets, we shouldn't log to syslog (but not
      #      doing that requires a logrotate config and smsd doesn't support SIGHUP).
      RuntimeDirectoryMode = "0750";
      StateDirectoryMode   = "0770";
      LogsDirectoryMode    = "0700";

      WorkingDirectory = "/run/sms";

      ExecStart = "${pkgs.smstools}/bin/smsd -t -c /run/sms/smsd.conf";
    };

    environment.INSTANCE = "%I";
    path = [ pkgs.smstools ];

    preStart = ''
      umask 077
      install -m 0400 -o smsd -g smsd $(realpath /etc/smsd.conf) /run/sms/smsd.conf
      if [ -e "${pinfile}" ] ; then
        echo "pin = $(cat ${pinfile})" >>/run/sms/smsd.conf
      fi
      sed -i '/^\s*device\s*=/ d' /run/sms/smsd.conf
      echo "device = /dev/$(basename "$INSTANCE")" >>/run/sms/smsd.conf

      for x in outgoing checked failed incoming report sent ; do
        install -m 0770 -o smsd -g smsd -d "/var/lib/sms/$x"
      done
    '';
  };
}
