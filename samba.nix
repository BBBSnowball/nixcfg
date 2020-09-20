{ config, pkgs, ... }:
{
  environment.systemPackages = [ pkgs.samba ];

  services.samba = {
    enable = true;
    extraConfig = ''
      log level = 1 auth:5 winbind:5
    '';
    shares = {
      scans = {
        path = "/home/scans";
        comment = "Target for scans from HP printer";
        browsable = "yes";
        "guest ok" = "no";
        "read only" = "no";
        writable = "yes";
        "valid users" = "scans";
      };
    };
  };

  networking.firewall.interfaces.br0.allowedTCPPorts = [ 139 445 ];
  services.shorewall.rules.samba = {
    proto = "tcp";
    destPort = [ 139 445 ];
  };

  users.users.scans = {
    isNormalUser = true;
    createHome = true;
    #NOTE Samba user must be added with `smbpasswd -a scans`. User shouldn't be able to login in Linux.
    hashedPassword = "x";
  };

  # stop annoying warning in syslog
  environment.etc.printcap.text = "";
}
