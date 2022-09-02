{ config, lib, pkgs, ... }:
{
  config = {
    #networking.networkmanager.unmanaged = [ "usb0" "usb1" ];
  
    systemd.services.usbnet = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "NetworkManager.service" ];
      serviceConfig.Type = "oneshot";
      serviceConfig.Restart = "on-failure";
      serviceConfig.RestartSec = 30;
      path = with pkgs; [ kmod networkmanager ];
  
      # see https://linux-sunxi.org/USB_Gadget/Ethernet
      # and https://github.com/hardillb/rpi-gadget-image-creator/blob/249ec983607d318012b39cb690d0543272fa27c8/usr/local/sbin/usb-gadget.sh-orig
      script = ''
        set -eu pipefail
        modprobe libcomposite
        cd /sys/kernel/config/usb_gadget
  
        echo "" >g1/UDC 2>/dev/null || true
        rm -rf g1 2>/dev/null || true
        rmdir g1/functions/* g1/configs/* g1 2>/dev/null || true
  
        mkdir g1
        cd g1
        echo "0x1d6b" > idVendor
        echo "0x0104" > idProduct
        mkdir functions/rndis.usb0
        mkdir configs/c1.1
        ln -s functions/rndis.usb0 configs/c1.1/
        mkdir functions/ecm.usb0
        mkdir configs/c1.2
        ln -s functions/ecm.usb0 configs/c1.2/
        mkdir functions/acm.usb0
        mkdir configs/c1.3
        ln -s functions/acm.usb0 configs/c1.3/
        echo musb-hdrc.2.auto >UDC

        sleep 1
        nmcli connection up usb0
        nmcli connection up usb1
      '';
    };

    systemd.services.NetworkManager.preStart = let
      makeNMConfig = iface: ip: pkgs.writeText "${iface}.nmconnection" ''
        [connection]
        id=${iface}
        uuid=${config.system.uuidForSystemPart "nmconnection-${iface}"}
        type=ethernet
        interface-name=${iface}

        [ethernet]

        [ipv4]
        address1=${ip}/29
        method=manual

        [ipv6]
        addr-gen-mode=stable-privacy
        method=auto

        [proxy]
      '';
    in ''
      if [ -d /etc/nixos/secret/nm-system-connections ] ; then
        mkdir -p /etc/NetworkManager/system-connections/
        install -m 600 ${makeNMConfig "usb0" "192.168.0.129"} /etc/NetworkManager/system-connections/usb0.nmconnection
        install -m 600 ${makeNMConfig "usb1" "192.168.0.137"} /etc/NetworkManager/system-connections/usb1.nmconnection
      fi
    '';
 
    services.dnsmasq = {
      enable = true;
      resolveLocalQueries = false;
      extraConfig = ''
        # Make it fast, no reason to be considerate towards other servers on our two-device network.
        dhcp-authoritative
        dhcp-rapid-commit
        no-ping
  
        interface=usb0
        interface=usb1
  
        # The netmask is /29, i.e. 8 addresses. First range is from 128 to 135, second range is from 136 to 143.
        dhcp-range=interface:usb0,192.168.0.130,192.168.0.134,255.255.255.248,10h
        dhcp-range=interface:usb1,192.168.0.138,192.168.0.142,255.255.255.248,10h
  
        # We don't want to send any gateway to the client. Does this work..? (option set with no value to override default)
        dhcp-option=option:router

        #FIXME is this useful?
        leasefile-ro
      '';
    };
    systemd.services.dnsmasq = let
      devs = [
        "sys-subsystem-net-devices-usb0.device"
        "sys-subsystem-net-devices-usb1.device"
      ];
    in {
      # BindsTo+After should be the right config for devices but that often stops dnsmasq
      # and doesn't start it again although the devices are active.
      #bindsTo = devs;
      requires = devs;
      after = devs;
    };
    networking.firewall.interfaces = let
      fw = {
        allowedUDPPorts = [ 67 config.services.iperf3.port ];
      };
    in { usb0 = fw; usb1 = fw; };
  
    services.iperf3 = {
      enable = true;
      #openFirewall = true;
    };
  };
}
