{ config, lib, pkgs, ... }:
let
  mkNet = start: length:
  assert lib.mod start length == 0;
  rec {
    getIpv4 = i: if i >= 0 then "192.168.0.${toString (start+i)}" else "192.168.0.${toString (start+length+i)}";
    ourIpv4 = getIpv4 1;
    netmask = if length == 8 then "255.255.255.248" else throw "We only support /29, for now.";
    dhcpRange = "${getIpv4 2},${getIpv4 (-2)},${netmask}";
  };
  # The netmask is /29, i.e. 8 addresses. First range is from 128 to 135, second range is from 136 to 143.
  nets = {
    usb0 = mkNet 128 8;
    usb1 = mkNet 136 8;
    usb0-vlan2 = mkNet 144 8 // { parent = "usb0"; vlan = 2; };
    usb1-vlan2 = mkNet 152 8 // { parent = "usb1"; vlan = 2; };
  };
in {
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

        # Can we have more than one network interface per configuration? (one for upstream traffic, the other in case we want to use GSM as the uplink)
        # -> Well, probably use VLANs instead to not waste USB endpoints for that.
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
      makeNMVLANConfig = iface: ip: vlan: pkgs.writeText "${iface}-vlan${toString vlan}.nmconnection" ''
        [connection]
        id=${iface}-vlan${toString vlan}
        uuid=${config.system.uuidForSystemPart "nmconnection-${iface}-vlan${toString vlan}"}
        type=vlan
        #autoconnect=false

        [ethernet]

        [vlan]
        flags=1
        id=${toString vlan}
        parent=${iface}

        [ipv4]
        address1=${ip}/29
        method=manual

        [ipv6]
        addr-gen-mode=stable-privacy
        method=auto

        [proxy]
      '';
      configs = lib.mapAttrs (k: v: if v ? vlan then makeNMVLANConfig v.parent v.ourIpv4 v.vlan else makeNMConfig k v.ourIpv4) nets;
    in ''
      if [ -d /etc/nixos/secret/nm-system-connections ] ; then
        mkdir -p /etc/NetworkManager/system-connections/
        ${lib.concatMapStringsSep "\n" (k: "install -m 600 ${configs."${k}"} /etc/NetworkManager/system-connections/${k}.nmconnection") (with builtins; sort (a: b: a<b) (attrNames configs))}
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
        interface=usb0.2
        interface=usb1.2
  
        dhcp-range=interface:usb0,${nets.usb0.dhcpRange},10h
        dhcp-range=interface:usb1,${nets.usb1.dhcpRange},10h
        dhcp-range=interface:usb0.2,${nets.usb0-vlan2.dhcpRange},10h
        dhcp-range=interface:usb1.2,${nets.usb1-vlan2.dhcpRange},10h
  
        # We don't want to send any gateway to the client. Does this work..? (option set with no value to override default)
        dhcp-option=interface:usb0,option:router
        dhcp-option=interface:usb1,option:router
        # We do want a gateway for VLAN 2 (because that is for using our GSM connection as a backup upstream).
        # -> Actually, don't do that because the metric of that route would be too low.
        #dhcp-option=interface:usb0.2,option:router,${nets.usb0-vlan2.ourIpv4}
        #dhcp-option=interface:usb1.2,option:router,${nets.usb1-vlan2.ourIpv4}
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
        allowedTCPPorts = [ config.services.iperf3.port ];
        allowedUDPPorts = [ 67 config.services.iperf3.port ];
      };
    in { usb0 = fw; usb1 = fw; "usb0.2" = fw; "usb1.2" = fw; };
  
    services.iperf3 = {
      enable = true;
      #openFirewall = true;
    };
  };
}
