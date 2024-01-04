{ pkgs, ... }:
{
  virtualisation.libvirtd.enable = true;
  users.users.user.extraGroups = [ "libvirtd" ];
  users.users.user.packages = with pkgs; [ virt-manager ];

  systemd.network.wait-online.ignoredInterfaces = [ "virbr0" ];

  #networking.firewall.logRefusedPackets = true;

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

