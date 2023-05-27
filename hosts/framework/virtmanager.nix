{ pkgs, ... }:
{
  virtualisation.libvirtd.enable = true;
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
  networking.firewall.interfaces.virbr0.allowedTCPPorts = [ 1883 ];

  networking.firewall.extraCommands = ''
    # forward port 8123 to HomeAssistant VM
    iptables -t nat -I PREROUTING -i wlp170s0 -p tcp --dport 8123 -j DNAT --to-destination 192.168.122.40
    iptables -I FORWARD -o virbr0 -p tcp --dport 8123 -j ACCEPT
  '';

  networking.firewall.logRefusedPackets = true;
}

