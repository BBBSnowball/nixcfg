# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, privateForHost, ... }@args:
let
  modules = args.modules or (import ../../modules.nix {});
  sshPublicPort = import "${privateForHost}/sshPublicPort.nix";
in {
  imports =
    (with modules; [
      ./hardware-configuration.nix
      ../../wifi-ap-eap/default.nix
      #../../sound.nix
      ./smokeping.nix
      #./ntopng.nix
      ./samba.nix
      ./tinc.nix
      shorewall
      ./dhcp-server.nix
      ./pppd.nix
      ./syslog-udp.nix
      ./rabbitmq.nix
      ./fhem.nix
      ./bambu.nix
      ./ddclient.nix
      ../../homeautomation
      snowball-headless-big
      ./msmtp.nix
      ./local-wifi.nix
    ]);

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  #boot.loader.efi.efiSysMountPoint = "/boot/efi";
  #boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.systemd-boot.editor = false;
  #FIXME It would be good to have something like boot.loader.grub.mirroredBoots but systemd-boot doesn't seem to support that.
  #  see https://github.com/systemd/systemd/issues/19668
  #  RAID is not an option either, see https://0pointer.net/blog/linux-boot-partitions.html, "Addendum: You got RAID?"
  #  -> Do rsync in boot.loader.systemd-boot.extraInstallCommands ..?

  # The bios sucks. It hangs in the POST screen after reboot. This might help:
  # https://serverfault.com/questions/126571/system-hangs-while-rebooting-on-debian/392886#392886
  boot.kernelParams = [ "reboot=hard,pci" ];

  networking.hostName = "routeromen";
  networking.domain = "local";
  networking.hostId = import "${privateForHost}/hostId.nix";
  networking.wireless.enable = false;

  networking.useNetworkd = true;
  networking.useDHCP = false;
  #networking.interfaces.enp4s0.useDHCP = true;
  #networking.interfaces.br0.useDHCP = true;
  #networking.dhcpcd.persistent = true;
  networking.interfaces.br0.macAddress = "a0:36:9f:35:33:70";
  networking.bridges.br0.interfaces = ["enp2s0f0" "enp2s0f1" "enp2s0f2" "enp2s0f3"];
  networking.interfaces.br0.ipv4 = {
    #addresses = [ { address = "192.168.178.59"; prefixLength = 24; } ];
    addresses = [
      { address = "192.168.89.185"; prefixLength = 24; }
      # dummy for local-wifi
      { address = "192.168.91.185"; prefixLength = 24; }
    ];
    #routes = [ {
    #  address = "0.0.0.0";
    #  prefixLength = 0;
    #  via = "192.168.89.3";
    #} ];
  };
  #networking.nameservers = [
  #  "192.168.89.3"
  #];
  systemd.network.wait-online.extraArgs = [ "--interface=br0" ];
  #FIXME make another wait-online service/target for pppoe-wan ?

  #services.hostapd.enable = true;
  services.hostapd.radios.wlp0s20f0u4.networks.x = {
    interface = "kl";
    ssid = "FRITZ!Box 7595";
    channel = 7;
    extraConfig = ''
      bridge=br0
      # use fast wifi, please (802.11n)
      ieee80211n=1
      ht_capab=[HT20-]
      #wme_enabled=1
      wmm_enabled=1

      # let radius server assign vlan
      dynamic_vlan=1
      vlan_bridge=br0
      vlan_file=/etc/nixos/wifi-ap-eap/all-vlans-on-br0.cfg

      # verbose logging
      #logger_stdout_level=0
    '';
  };
  services.wifi-ap-eap = {
#   enable = true;
    countryCode = "DE";
    serverName = "ap.verl.bbbsnowball.de";
    #wifiFourAddressMode = true;
    serverCertValidDays = 3650;
    clientCertValidDays = 3650;
  };
  #services.freeradius.debug = true;


  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    wget byobu tmux tig cifs-utils pv file killall
    #vim
    htop iotop iftop cpufrequtils inteltool powertop stress stress-ng sysprof nethogs nix-top unixtools.top usbtop lzop
    #FIXME throttled undervolt
    # atop ctop dnstop gotop nettop latencytop netatop gtop powerstat rPackages.gtop vtop
    # numatop nvtop pg_top radeontop
    pciutils usbutils lm_sensors
    smartmontools
    multipath-tools  # kpartx
    hdparm
    iperf iperf3
    utillinux parted
    bmon
    progress
    nix-index
    inetutils
    lsof
    #linuxPackages.wireguard
    wireguard-tools

    qemu_kvm
    wirelesstools iw

    neovim neovim-remote fzf ctags
    # only in nixos unstable: page

    #emacs-nox
    config.services.emacs.package
    sqlite-interactive
    #iptables-nftables-compat

    direnv
    man-pages-posix
    dnsutils
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = { enable = true; enableSSHSupport = true; };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  services.openssh.ports = [ 22 sshPublicPort ];
  services.shorewall.rules.ssh.rules = [{
    proto = "tcp";
    destPort = sshPublicPort;
    source = "all";
    dest = "$FW";
  } {
    proto = "tcp";
    destPort = 22;
    source = "tinc";
    dest = "$FW";
  }
  # We get lots of these because of tailscale.
  {
    proto = "udp";
    destPort = 5351;
    source = "loc";
    dest = "$FW";
    action = "REJECT";
  }
  {
    proto = "udp";
    destPort = 1900;
    source = "loc";
    dest = "$FW";
    action = "REJECT";
  }];

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable the X11 windowing system.
  # services.xserver.enable = true;
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e";

  # Enable touchpad support.
  # services.xserver.libinput.enable = true;

  # Enable the KDE Desktop Environment.
  # services.xserver.displayManager.sddm.enable = true;
  # services.xserver.desktopManager.plasma5.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.mutableUsers = false;
  users.users.benny = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    hashedPassword = import "${privateForHost}/hashedPassword.nix";
    openssh.authorizedKeys.keyFiles = [ "${privateForHost}/ssh-laptop.pub" ];
  };
  users.users.root = {
    hashedPassword = import "${privateForHost}/hashedPassword.nix";
    openssh.authorizedKeys.keyFiles = [ "${privateForHost}/ssh-laptop.pub" ];
  };
  users.groups.test = {};
  users.users.test = {
    isNormalUser = true;
    hashedPassword = import "${privateForHost}/hashedPassword.nix";
    openssh.authorizedKeys.keyFiles = [ "${privateForHost}/ssh-laptop.pub" ];
    packages = with pkgs; [
      anbox apktool
      #android-studio # unfree :-(
      #androidenv.androidPkgs_9_0.platform-tools  # contains adb
      #androidenv.androidPkgs_9_0.androidsdk
      #adoptopenjdk-bin  # contains keytool and jarsigner
      nodePackages.node2nix
    ];
    extraGroups = [
      "audio"
      "test"
    ];
  };
  nixpkgs.config.android_sdk.accept_license = true;
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "android-studio"
    "android-studio-stable"
    "android-sdk-tools"
    "android-sdk-cmdline-tools"
  ];
  users.users.remoteBuild = {
    isNormalUser = true;
    hashedPassword = "!";
    openssh.authorizedKeys.keyFiles = [ "${privateForHost}/ssh-laptop.pub" "${privateForHost}/ssh-gpd.pub" ];
  };
  users.users.test_nonet = {
    isNormalUser = true;
    hashedPassword = import "${privateForHost}/hashedPassword.nix";
    openssh.authorizedKeys.keyFiles = [ "${privateForHost}/ssh-laptop.pub" ];
    extraGroups = [
      "test"
    ];
  };

  #users.defaultLinger = true;
  #users.users.root.linger = true;

  services.shorewall.rules.test_nonet.rules = [
    { action = "REJECT"; source = "$FW"; dest = "all"; extraFields = "- - test_nonet"; }
  ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  services.lorri.enable = true;

  documentation.dev.enable = true;

  services.shorewall.rules.mosh.rules = [
    { source = "all"; dest = "$FW"; proto = "udp"; destPort = "60000:61000"; }
  ];

  nix.registry = lib.mkIf (args ? self) { routeromen.flake = args.self; };

  nix.settings.secret-key-files = [ "/etc/nixos/secret_local/cache-priv-key.pem" ];

  services.prometheus.exporters.node.enable = true;
  services.prometheus.exporters.node.enabledCollectors = [ "ethtool" "qdisc" "systemd" "wifi"
    #"perf"
  ];
  services.prometheus.pushgateway.enable = true;

  # mdmonitor service is added by mdadm package and it will fail if we don't configure this.
  # (msmtp will resolve "root" to the intended recipient via aliases.)
  environment.etc."mdadm.conf".text = ''
    MAILADDR root
  '';

  services.shorewall.rules.zigbee2mqtt = {
    proto = "tcp";
    destPort = [ config.services.zigbee2mqtt.settings.frontend.port ];
    source = "loc,tinc:192.168.84.50";
  };

  services.tailscale.enable = true;

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "19.09"; # Did you read the comment?

}

