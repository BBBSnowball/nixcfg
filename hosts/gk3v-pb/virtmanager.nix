{ pkgs, ... }:
{
  virtualisation.libvirtd = {
    enable = true;
    allowedBridges = [ "br0" ];
  };
  users.users.user.extraGroups = [ "libvirtd" ];
  users.users.user.packages = with pkgs; [ virt-manager ];

  networking.firewall.extraCommands = ''
    # mark packets that are coming in from a VM interface
    if ebtables -N vm 2>/dev/null ; then
      ebtables -I INPUT -j vm
      ebtables -I FORWARD -j vm
    else
      ebtables -F vm
    fi
    ebtables -A vm -i vnet+ -j mark --mark-set 0xf0 --mark-target ACCEPT

    # allow access to MQTT for VMs
    iptables -I nixos-fw 3 -i br0 -p tcp -m mark --mark 0xf0 -m tcp --dport 1883 -j ACCEPT

    # allow access to z2m from fw via tinc
    iptables -I nixos-fw 3 -s 192.168.83.139/32 -i tinc.a -p tcp -m tcp --dport 8086 -j ACCEPT
    # also from xps
    iptables -I nixos-fw 3 -s 192.168.83.50/32 -i tinc.a -p tcp -m tcp --dport 8086 -j ACCEPT
    iptables -I nixos-fw 3 -s 192.168.84.50/32 -i tinc.bbbsnowbal -p tcp -m tcp --dport 8086 -j ACCEPT
  '';

  #networking.firewall.logRefusedPackets = true;

  # How to create the bridge with Network Manager:
  # https://www.cyberciti.biz/faq/how-to-add-network-bridge-with-nmcli-networkmanager-on-linux/
  #
  # nmcli con add type bridge ifname br0
  # nmcli con add type bridge-slave ifname enp2s0 master br0
  # nmcli con modify bridge-br0 bridge.stp no
  # nmcli con modify bridge-br0 bridge.mac-address ... # clone MAC of ethernet iface
  # nmcli con down "Wired connection 1"
  # nmcli con up bridge-br0
  # 

  # How to setup Home Assistant:
  # see https://www.home-assistant.io/installation/linux
  # see https://myme.no/posts/2021-11-25-nixos-home-assistant.html (useful info but I didn't use any of it in the end)
  #
  # We need UEFI. I couldn't set it in VirtManager but this works:
  #   <os>
  #     <type arch='x86_64' machine='pc-q35-8.0'>hvm</type>
  #+    <loader readonly='yes' type='pflash'>/run/libvirt/nix-ovmf/OVMF_CODE.fd</loader>
  #+    <nvram>/var/lib/libvirt/qemu/nvram/HomeAssistant_VARS.fd</nvram>
  #     ...
  #   </os>
  #
  # We do not need to open any ports because we are bridging the VM to the network.
}

