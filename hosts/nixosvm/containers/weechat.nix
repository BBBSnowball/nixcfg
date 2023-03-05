{ config, lib, modules, pkgs, private, ... }:
let
  privateForHost = "${private}/by-host/${config.networking.hostName}";
  ports = config.networking.firewall.allowedPorts;
in {
  containers.weechat = {
    autoStart = true;
    config = { config, pkgs, ... }: let
    in {
      imports = [ modules.container-common ];

      environment.systemPackages = with pkgs; [
        socat weechat bitlbee
      ];

      users.users.user = {
        isNormalUser = true;
        extraGroups = [ ];
        uid = 1495;
        openssh.authorizedKeys.keyFiles = [ "${privateForHost}/ssh-laptop.pub" ];
      };

      services.bitlbee = {
        enable = true;
        interface = "127.0.0.1";
        authMode = "Registered";
        plugins = with pkgs; [ ];
        libpurple_plugins = with pkgs; [ purple-matrix purple-signald purple-discord ];
      };

      services.stunnel = {
        enable = true;
        # http://www.datenzone.de/blog/2012/01/using-ssltls-client-certificate-authentification-in-android-applications/
        servers.weechat-relay = {
          cert = "/etc/ssl/stunnel/cert-server.pem";
          key = "/etc/ssl/stunnel/key-server.pem";
          CAfile = "/etc/ssl/stunnel/cert-client.pem";
          #sslVersion = SSLv3
          #socket = [
          #  "l:TCP_NODELAY=1"
          #  "r:TCP_NODELAY=1"
          #];
          #FIXME We want to set it for "l:" and "r:" but the NixOS module doesn't let us do that.
          socket = "r:TCP_NODELAY=1";
          
          accept  = ports.weechat-relay.port;
          connect = "127.0.0.1:4242";
          verify = "2";
        };
        # http://wiki.bitlbee.org/Oscar%20over%20SSL
        clients.oscaricq = {
          accept = "127.0.0.1:5190";
          connect = "slogin.icq.com:443";
        };
      };

      # There is a ready-made service for WeeChat in screen
      # but some networks consider it rude to auto-connect
      # without user interaction so let's keep the old, manual
      # way of starting it, for now.
      #services.weechat.enable = true;
    };
  };

  networking.firewall.allowedPorts.weechat-relay = 4030;

  systemd.services."container@weechat.service" = {
    #overrideStrategy = "asDropin";
    stopIfChanged = false;
    restartIfChanged = false;
  };
}
