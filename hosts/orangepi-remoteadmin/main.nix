{ config, pkgs, lib, routeromen, withFlakeInputs, private, ... }:
let
  basicUser = {
    # generate contents with `mkpasswd -m sha-512`
    passwordFile = "/etc/nixos/secret/rootpw";

    openssh.authorizedKeys.keyFiles = [
      "${private}/ssh-laptop.pub"
      "${private}/ssh-framework-user.pub"
      "${private}/ssh-framework-root.pub"
    ];
  };
  rootUser = basicUser;
  normalUser = basicUser // {
    isNormalUser = true;

    packages = with pkgs; [
    ];

    extraGroups = [ "dialout" ];
  };
in {
  imports =
    with routeromen.nixosModules; [
      snowball-headless
      network-manager
      #tinc-client-a
    ] ++
    [ ./orangpi-pc2.nix
      ./orangpi-installer.nix
      ./wwan.nix
      ./usbnet.nix
      (withFlakeInputs ./tincs.nix)
    ];

  #boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelPackages = pkgs.linuxPackages;
  boot.extraModulePackages = [
    (config.boot.kernelPackages.callPackage ../gpd/rtl8188gu.nix {})
  ];

  boot.tmpOnTmpfs = true;

  networking.hostName = "orangepi-remoteadmin";

  system.baseUUID = builtins.readFile "${private}/baseUUID";

  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;

  users.users.user = normalUser;
  users.users.root = rootUser;

  environment.systemPackages = with pkgs; [
    mosh
    tcpdump
  ];

  # for mosh
  networking.firewall.allowedUDPPortRanges = [ { from = 60000; to = 61000; } ];

  nix.registry.routeromen.flake = routeromen;

  # Route traffic to wwan interface if anyone decides to send any traffic to us.
  # omen-verl will have such a route on its usbnet so its uplink will automatically
  # switch when the usual uplink is down. Other hosts can choose to set a default
  # route to the Ethernet or WiFi address of this host but this is mostly useful
  # for debugging the modem uplink.
  networking.nat = {
    enable = true;
    externalInterface = "wwan0";
    # This only uses fwmark to disable masquerading but we have to filter the packets.
    # -> but it seems to be required.
    #NOTE This is using fwmark 0x1 so we mustn't use this for other purposes!
    internalInterfaces = [ "usb0.2" "usb1.2" "wlan0" "eth0" ];
    extraCommands = ''
      # These must be here rather than in networking.firewall.extraCommands
      # because they must run after NixOS' commands.
      #
      # Where should we add them?
      # - -t nat -A PREROUTING -> would run before NixOS' rules so fwmark would be 1
      # - -t nat -A nixos-nat-pre -> works but only for the first packet of a "connection"
      # - -t raw -A PREROUTING -> should run for every packet -> and is then overridden by NixOS' rules
      ip46tables -t raw -N mark-for-modem 2> /dev/null || true
      ip46tables -t raw -F mark-for-modem 2> /dev/null || true
      ip46tables -t raw -D PREROUTING -j mark-for-modem 2> /dev/null || true
      ip46tables -t raw -A PREROUTING -j mark-for-modem 2> /dev/null || true
      iptables -t raw -A mark-for-modem -i usb0.2 ! --dst 192.168.0.0/16 -j MARK --set-mark 3
      iptables -t raw -A mark-for-modem -i usb1.2 ! --dst 192.168.0.0/16 -j MARK --set-mark 3
      iptables -t raw -A mark-for-modem -i wlan0  ! --dst 192.168.0.0/16 -j MARK --set-mark 3
      iptables -t raw -A mark-for-modem -i eth0   ! --dst 192.168.0.0/16 -j MARK --set-mark 3

      # kill NixOS' rules because we want to keep our fwmark
      # Sorry about the brute-force method.
      iptables -t nat -F nixos-nat-pre

      # our marks disrupt NixOS' masquerading rule so add one for fwmark 3
      iptables -t nat -A nixos-nat-post -o wwan0 -m mark --mark 0x3 -j MASQUERADE

      # The rpfilter of NixOS' seems to drop incoming packets on wwan0 - probably because of our
      # trickery with the routing tables.
      iptables -t raw -I nixos-fw-rpfilter -i wwan0 -j RETURN
    '';
  };
  networking.firewall.extraCommands = ''
    ip46tables -P FORWARD DROP
    ip46tables -F FORWARD  ;# NixOS doesn't seem to add any rules in here anyway
    ip46tables -I FORWARD -i wwan0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    ip46tables -A FORWARD -i usb0.2 -o wwan0 -j ACCEPT
    ip46tables -A FORWARD -i usb1.2 -o wwan0 -j ACCEPT
    ip46tables -A FORWARD -i wlan0 -o wwan0 -j ACCEPT
    ip46tables -A FORWARD -i eth0 -o wwan0 -j ACCEPT
    #NOTE Default limit is 3/hour with limit-burst=5. We keep that, for now.
    ip46tables -A FORWARD -j LOG --log-prefix "refused forward: " --log-level 6
    ip46tables -A FORWARD -i wwan0 -j DROP
    ip46tables -A FORWARD -j REJECT

    iptables -F OUTPUT
    iptables -A OUTPUT -o wwan0 --src 192.168.0.0/16 -j LOG --log-prefix "refused sending to wwan: " --log-level 6
    iptables -A OUTPUT -o wwan0 --dst 192.168.0.0/16 -j LOG --log-prefix "refused sending to wwan: " --log-level 6
    iptables -A OUTPUT -o wwan0 --src 192.168.0.0/16 -j REJECT
    iptables -A OUTPUT -o wwan0 --dst 192.168.0.0/16 -j REJECT

    #ip46tables -A OUTPUT -m owner --uid-owner tinc.a-modem -j MARK --set-mark 3
    # https://superuser.com/a/1453850
    # -> This is after routing (but probably "mangle" triggers routing again).
    ip46tables -t mangle -A OUTPUT -m owner --uid-owner tinc.a-modem -j MARK --set-mark 3
    # Further rules for fwmark are in networking.nat.extraCommands - see above.

    # Packets with fwmark 3 go to wwan.
    PATH=$PATH:${pkgs.iproute2}/bin
    if [ "$(ip rule show fwmark 3)" == "" ] ; then
      ip rule add priority 1000 fwmark 3 lookup wwan
    fi
    # Add wwan also as a last resort option with very low priority.
    if [ "$(ip rule show priority 100000 lookup wwan)" == "" ] ; then
      ip rule add priority 100000 lookup wwan
    fi
  '';

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.05"; # Did you read the comment?
}
