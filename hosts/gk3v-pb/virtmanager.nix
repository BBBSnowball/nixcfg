{ pkgs, ... }:
let
  iface1 = "enp2s0";
  iface2 = "wlp3s0";
  vmIp = "192.168.122.40";
  webPort = 8123;
in
{
  virtualisation.libvirtd = {
    enable = true;
    allowedBridges = [ "br0" ];
  };
  users.users.user.extraGroups = [ "libvirtd" ];
  users.users.user.packages = with pkgs; [ virtmanager ];

  # not available anymore, it seems
#  services.virtlyst.enable = true;
#  services.virtlyst.adminPassword = "password";  # Well....
#  # SSH doesn't seem to be tested - at least for the Nix package.
#  # In addition, I had to create ~virtlyst/.ssh/{id_rsa,config,known_hosts}
#  # with appropriate contents. I have set the user in the SSH config because
#  # the user field on the web interface seems to be ignored (but I probably
#  # could have added it to the hostname).
#  systemd.services.virtlyst.path = [ pkgs.openssh ];

  # Home Assistant is allowed to access our MQTT broker.
  #networking.firewall.interfaces.virbr0.allowedTCPPorts = [ 1883 ];

  #networking.firewall.extraCommands = ''
  #  # forward port 8123 to HomeAssistant VM
  #  iptables -t nat -I PREROUTING -i ${iface1} -p tcp --dport ${webPort} -j DNAT --to-destination ${vmIp}
  #  iptables -t nat -I PREROUTING -i ${iface2} -p tcp --dport ${webPort} -j DNAT --to-destination ${vmIp}
  #  iptables -I FORWARD -o virbr0 -p tcp --dport ${webPort} -j ACCEPT
  #'';

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
  # virsh nwfilter-define home-assistant-open-ports.xml
  # Edit VM:
  #   <interface type='network'>
  #     <filterref filter='home-assistant-open-ports'/>  <!-- add this line -->
  #     ...
  #   </interface>
  # Edit network (virsh net-edit --network default)
  # <network xmlns:dnsmasq='http://libvirt.org/schemas/network/dnsmasq/1.0'>
  #   ...
  #   <dnsmasq:options>
  #     <dnsmasq:option value="interface=virbr0"/>
  #     <dnsmasq:option value="bind-interfaces"/>  <!-- removed later because not accepted -->
  #   </dnsmasq:options>
  # </network>

  #networking.bridges.virbr0 = {
  #  interfaces = [];
  #};
  #networking.interfaces.virbr0 = {
  #  ipv4.addresses = [ {
  #    address = "192.168.122.1";
  #    prefixLength = 24;
  #  } ];
  #};
  #
  # -> won't work, we have to use: virsh net-start default
}

