{ config, pkgs, lib, routeromen, private, withFlakeInputs, ... }:

let
  privateForHost = "${private}/by-host/${config.networking.hostName}";
  privateInitrd = import "${privateForHost}/initrd.nix" { testInQemu = false; };
  privateValues = import privateForHost;

  serverExternalIp = config.networking.externalIp;
in {
  imports =
    [ (withFlakeInputs ../sonline0-initrd/main.nix)
      #namedFirewallPorts
      ./firewall-iptables-restore-simple.nix
      routeromen.nixosModules.snowball-headless
      routeromen.nixosModules.nixcfg-sync
      ./vms.nix
      ./kexec.nix
      ./ipv6.nix
      ./backup.nix
    ];

  boot.loader.grub.devices = [
    "/dev/sda"
    "/dev/sdb"
    "/dev/sdc"
  ];

  environment.systemPackages = with pkgs; [
    iptables
    ruby
    tcpdump
  ];

  #networking.firewall.enable = true;
  networking.firewall.iptables-restore.enable = true;
  services.openssh.ports = [ privateInitrd.port ];

  boot.kernel.sysctl."net.ipv4.ip_forward" = "1";

  systemd.network = {
    enable = true;
    wait-online.ignoredInterfaces = [ "enp1s0f1" "br84" ];

    # I wanted to change the actual name for iptables but that didn't work.
    # The alias does work after kicking udev
    # (udevadm trigger -c add sys-subsystem-net-devices-enp1s0f0.device).
    # It might work after a reboot or we might have to use udev rules like
    # we did on the old Debian system.
    # (see /media/restore/x/etc/udev/rules.d/70-persistent-net.rules)
    # -> It seems easier to change the iptables rules rather than banging our
    #    heads against this any further.
    # -> We deactivate the "Name=..." because we don't want it to unexpectedly
    #    start working at some point.
    links."10-eth0" = {
      matchConfig.OriginalName = "enp1s0f0";
      #matchConfig.MACAddress = "...";
      #linkConfig.Name = "eth0";
      linkConfig.Alias = "eth0";
    };
    links."10-eth1" = {
      matchConfig.OriginalName = "enp1s0f1";
      #matchConfig.OriginalName = "*";
      #matchConfig.MACAddress = "...";
      #linkConfig.Name = "eth1";
      linkConfig.Alias = "eth1";
    };

    networks.enp1s0f0 = {
      name = "enp1s0f0";
      # all static, nothing from DHCP - We don't want to find out the hard way
      # whether the infra protects us against DHCP spoofing.
      address = [
        "${privateValues.net.ip0}/24"
        "${privateValues.net.ip1}/32"
        "${privateValues.net.ip2}/32"
        "${privateValues.net.ipv6}"
      ];
      gateway = [ privateValues.net.gw ];
      dns = privateValues.net.nameservers;
      # Well, that's what Scaleway says we have to do. Let's hope that spoofing
      # isn't possible.
      extraConfig = ''
        [Network]
        IPv6AcceptRA=true
      '';
    };

    networks.vm = {
      name = "vm-*";
      bridge = [ "br84" ];
    };

    networks.br84 = {
      name = "br84";
      address = [
        "${privateValues.net.internalPrefix}.129/24"
      ];
      extraConfig = ''
        [Bridge]
        HairPin=true
      '';
    };
    netdevs.br84 = {
      netdevConfig = {
        Kind = "bridge";
        Name = "br84";
      };
    };
  };
  # Let's not trust our neighbors to do name resolution for us.
  # Check with: systemd-resolve --status
  services.resolved = {
    llmnr = "false";
    extraConfig = ''
      MulticastDNS=false
    '';
  };

  virtualisation.kvm.autoStart = [ "mailinabox" "nixos" "c3pb" ];

  users.mutableUsers = false;
  # generate contents with `mkpasswd -m sha-512`
  users.users.root.passwordFile = "/etc/nixos/secret/by-host/${config.networking.hostName}/rootpw";
  users.users.${privateValues.userName} = {
    isNormalUser = true;
    openssh.authorizedKeys.keyFiles = [
      "${privateForHost}/ssh-laptop.pub"
      "${privateForHost}/ssh-routeromen.pub"
    ];
    extraGroups = [ "wheel" ];
  };
  users.users.portfwd = {
    isNormalUser = true;
  };
  users.users.test = {
    isNormalUser = true;
  };
  security.sudo = {
    enable = true;
    execWheelOnly = true;
    wheelNeedsPassword = false;
  };
  #nix.settings.trusted-users = [ "root" "@wheel" ];
  nix.settings.trusted-public-keys = privateValues.trusted-public-keys;

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "22.11"; # Did you read the comment?
}
