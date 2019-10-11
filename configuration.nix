# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

let
  ssh_keys = [
    #(builtins.readFile ./private/ssh-some-admin-key.pub)
    (builtins.readFile ./private/ssh-laptop.pub)
    (builtins.readFile ./private/ssh-dom0.pub)
  ];

  serverExternalIp = <redacted>;
  upstreamIP = (builtins.head config.networking.interfaces.ens3.ipv4.addresses).address;
  tincIP     = (builtins.head config.networking.interfaces."tinc.bbbsnowbal".ipv4.addresses).address;

  favoritePkgs = with pkgs; [ wget htop tmux byobu git vim tig ];

  myDefaultConfig = { config, pkgs, ...}: {
    environment.systemPackages = favoritePkgs ++ [ pkgs.vi-alias ];
    users.users.root.openssh.authorizedKeys.keys = ssh_keys;
    programs.vim.defaultEditor = true;
    nixpkgs.overlays = [ (self: super: {
      vim = super.pkgs.vim_configurable.customize {
        #NOTE This breaks the vi->vim alias.
        name = "vim";
        vimrcConfig.customRC = ''
          imap fd <Esc>
        '';
      };
      vi-alias = self.buildEnv {
        name = "vi-alias";
        paths = [
          (self.pkgs.writeShellScriptBin "vi" ''exec ${pkgs.vim}/bin/vim "$@"'')
        ];
      };
      # vimrc is an argument, not a package
      #vimrc = self.runCommand "my-vimrc" {origVimrc = super.vimrc;} ''cp $origVimrc $out ; echo "imap fd <Esc>" >> $out'';
      # infinite recursion because vim in super tries to use the new vimrc
      #vimrc = self.runCommand "my-vimrc" {origVim = super.vim;} ''cp $origVim/share/vim/vimrc $out ; echo "imap fd <Esc>" >> $out'';
      # rebuilds vim
      #vim = super.vim.override { vimrc = self.runCommand "my-vimrc" {origVim = super.vim;} ''cat $origVim/share/vim/vimrc >$out ; echo "imap fd <Esc>" >> $out''; };
    }) ];
  };

  opensshWithUnixDomainSocket = { config, pkgs, ... }: {
    services.openssh.enable = true;
    services.openssh.startWhenNeeded = true;
    services.openssh.openFirewall = false;
    services.openssh.listenAddresses = [{addr="127.0.0.1"; port=2201;}];  # dummy
    systemd.sockets.sshd.socketConfig.ListenStream = pkgs.lib.mkForce "/sshd.sock";
  };

  namedFirewallPorts = { config, pkgs, ... }: with lib; let
    portType = types.addCheck (types.submodule {
      options = {
        port = mkOption { type = types.nullOr types.port; default = null; };
        from = mkOption { type = types.nullOr types.port; default = null; };
        to   = mkOption { type = types.nullOr types.port; default = null; };
        type = mkOption { type = types.enum [ "tcp" "udp" ]; };
      };
    }) (x: (x.port != null && x.from == null && x.to == null) || (x.port == null && x.from != null && x.to != null));
    portTypeOrPort = types.coercedTo types.port (port: { inherit port; type = "tcp"; }) portType;
    allowedPortsType = types.attrsOf portTypeOrPort;
  in {
    options = {
      networking.firewall.allowedPortsInterface = mkOption {
        type = types.string;
        default = "";
        example = "eth0";
        description = "open ports in allowedPorts on specific interface; use \"\" for all interfaces";
      };
      networking.firewall.allowedPorts = mkOption {
        type = allowedPortsType;
        default = {};
        example = { ssh = 22; dns = { port = 53; type = "udp"; }; };
        description = "an attr-valued variant of allowedTcpPorts et. al. (so values can be set in different places more easily)";
      };
    };

    config = let
      filterType = type: attrs: filter (x: x.type == type) (attrValues attrs);
      extractPorts  = portAttrs: map (x: x.port)                   (filter (x: x.port != null) portAttrs);
      extractRanges = portAttrs: map (x: { inherit (x) from to; }) (filter (x: x.from != null) portAttrs);
      duplicatePorts = ports: let
        normalizedPorts = lib.attrsets.mapAttrsToList (name: value: with value; {
          inherit name type;
          from = (if from != null then from else port);
          to   = (if from != null then to   else port);
        }) ports;
        sorted = builtins.sort (a: b: (lib.lists.compareLists lib.trivial.compare [a.type a.from a.to] [b.type b.from b.to]) < 0) normalizedPorts;
        check = a: b: optional (a.type == b.type && a.to >= b.from) { type = a.type; a = a.name; b = b.name; port = b.from; };
        duplicates = builtins.concatLists (lib.lists.zipListsWith check sorted (lib.lists.drop 1 sorted));
      in duplicates;
      check = x:
        let dup = duplicatePorts config.networking.firewall.allowedPorts;
          in assert lib.asserts.assertMsg (dup == []) ("duplicate ports: " + builtins.toJSON dup);
        x;
      firewallOptions = check {
        allowedTCPPorts      = extractPorts  (filterType "tcp" config.networking.firewall.allowedPorts);
        allowedUDPPorts      = extractPorts  (filterType "udp" config.networking.firewall.allowedPorts);
        allowedTCPPortRanges = extractRanges (filterType "tcp" config.networking.firewall.allowedPorts);
        allowedUDPPortRanges = extractRanges (filterType "udp" config.networking.firewall.allowedPorts);
      };
      iface = config.networking.firewall.allowedPortsInterface;
    #NOTE Useful functions for debugging: abort, builtins.toXML, builtins.toJSON, builtins.trace
    in {
      #NOTE We have to "tell" Nix which attributes we might be setting before we can use any config options.
      #     Otherwise, we will end up with infinite recursion.
      networking.firewall.allowedTCPPorts       = if iface == "" then firewallOptions.allowedTCPPorts      else {};
      networking.firewall.allowedUDPPorts       = if iface == "" then firewallOptions.allowedUDPPorts      else {};
      networking.firewall.allowedTCPPortRanges  = if iface == "" then firewallOptions.allowedTCPPortRanges else {};
      networking.firewall.allowedUDPPortRanges  = if iface == "" then firewallOptions.allowedUDPPortRanges else {};
      networking.firewall.interfaces."${iface}" = if iface != "" then firewallOptions                      else {};
    };
  };

  ports = config.networking.firewall.allowedPorts;
in {
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
      myDefaultConfig
      namedFirewallPorts
    ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  # boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only
  boot.loader.grub.device = "/dev/vda";

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n = {
  #   consoleFont = "Lat2-Terminus16";
      consoleKeyMap = "de";
      defaultLocale = "en_US.UTF-8";
  };

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    socat
    # not with programs.mosh.enable because we want to do firewall ourselves
    mosh
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = { enable = true; enableSSHSupport = true; };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  networking.interfaces.ens3.ipv4.addresses = [ {
    address = "192.168.84.133";
    prefixLength = 25;
  } ];
  networking.useDHCP = false;

  networking.defaultGateway = "192.168.84.129";
  networking.nameservers = [ "62.210.16.6" "62.210.16.7" ];

  networking.interfaces."tinc.bbbsnowbal".ipv4.addresses = [ {
    address = "192.168.84.39";
    prefixLength = 25;
  } ];
  networking.interfaces."tinc.door".ipv4.addresses = [ {
    address = "192.168.19.39";
    prefixLength = 25;
  } ];


  networking.firewall.enable = true;

  networking.firewall.rejectPackets = true;
  networking.firewall.pingLimit = "--limit 100/minute --limit-burst 20";
  #FIXME This is *UGLY*. I should change to a iptables-restore based flow asap.
  #      NixOS has an issue for that but that has been open for years:
  #      https://github.com/NixOS/nixpkgs/issues/4155
  networking.firewall.extraCommands = ''
    iptables -w -F FORWARD
    iptables -w -F fw-reject || true
    iptables -w -X fw-reject || true
    iptables -w -N fw-reject
    iptables -w -A fw-reject -m limit --limit 10/minute --limit-burst 5 -j LOG --log-prefix "refused forward: " --log-level 6
    iptables -w -A fw-reject -j REJECT
    iptables -w -A FORWARD -i vpn_android-+ -o tinc.bbbsnowbal -p tcp -d 192.168.84.36 --dport 443 -j ACCEPT  # calendar
    iptables -w -A FORWARD -o vpn_android-+ -i tinc.bbbsnowbal -p tcp -s 192.168.84.36 --sport 443 -j ACCEPT
    iptables -w -A FORWARD -i vpn_android-+ -o tinc.bbbsnowbal -p tcp -d 192.168.84.47 --dport 80 -j ACCEPT  # fhem
    iptables -w -A FORWARD -o vpn_android-+ -i tinc.bbbsnowbal -p tcp -s 192.168.84.47 --sport 80 -j ACCEPT
    iptables -w -A FORWARD -i vpn_+ -o ens3 -d 192.168.0.0/16,127.0.0.0/8 -j fw-reject
    iptables -w -A FORWARD -i vpn_+ -o ens3 -j ACCEPT
    iptables -w -A FORWARD -o vpn_+ -i ens3 -j ACCEPT
    iptables -w -A FORWARD -j fw-reject
    iptables -w -t nat -F POSTROUTING
    iptables -w -t nat -A POSTROUTING -o ens3 -j MASQUERADE
    ip6tables -w -F FORWARD
    ip6tables -w -A FORWARD -j REJECT

    iptables -w -t nat -F PREROUTING
    iptables -w -t nat -A PREROUTING -i vpn_android-+ -d 192.168.112.10/32 -p tcp --dport 80 -j DNAT --to-destination ${upstreamIP}:${toString ports.rss.port}
    iptables -w -t nat -A PREROUTING -i vpn_android-+ -d 192.168.118.10/32 -p tcp --dport 80 -j DNAT --to-destination ${upstreamIP}:${toString ports.notes-magpie-ext.port}
    # Dummy port, copied from old VPN on kim: 1743 on public IP of Kim is redirected to 443 on gallery for access to Davical/calendar
    iptables -w -t nat -A PREROUTING -i vpn_android-+ -s 192.168.88.0/23 -d 37.187.106.83/32 -p tcp --dport 1743 -j DNAT --to-destination 192.168.84.36:443
    iptables -w -t nat -I POSTROUTING -s 192.168.88.0/23 -d 192.168.84.36/32 -o tinc.bbbsnowbal -j MASQUERADE  # adjust source IP so tinc can handle the packets

    #TODO The second rule is required for the first rule to work and we need a route on bbverl:
    # route add -host 192.168.88.2 gw 192.168.84.37
    #allow_port_forward(in_iface, "bbbsnowball-dev", "192.168.84.47", :tcp, 80)
    #dnat_port_forward(in_iface, "192.168.85.47", :tcp, 80, "bbbsnowball-dev", "192.168.84.47", 80)
    iptables -w -t nat -A PREROUTING -i vpn_android-+ -s 192.168.88.0/23 -d 192.168.85.47/32 -p tcp --dport 80 -j DNAT --to-destination 192.168.84.47:80
    iptables -w -t nat -I POSTROUTING -s 192.168.88.0/23 -d 192.168.84.47/32 -o tinc.bbbsnowbal -j MASQUERADE  # adjust source IP so tinc can handle the packets

    #TODO We shoud properly filter incoming packets from VPN: deny from vpn_+ in INPUT, allow "--icmp-type destination-unreachable", whitelist appropriate ports
    #TODO This should already be rejected in FORWARD but this is not logged and connection times out instead.
    iptables -w -t nat -A PREROUTING -i vpn_+ -d 192.168.0.0/16 -p tcp -j DNAT --to-destination 127.0.0.2:1
    iptables -w -t nat -A PREROUTING -i vpn_+ -d 192.168.0.0/16 -p udp -j DNAT --to-destination 127.0.0.2:1
  '';

  boot.kernel.sysctl."net.ipv4.ip_forward" = "1";

  networking.firewall.interfaces."tinc.bbbsnowbal".allowedUDPPortRanges = [
    # mosh
    { from = 60000; to = 61000; }
  ];

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
  # users.users.jane = {
  #   isNormalUser = true;
  #   extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  # };
  #users.users.root.openssh.authorizedKeys.keys = ssh_keys;

  #headless = true;
  sound.enable = false;
  boot.vesa = false;
  boot.loader.grub.splashImage = null;

  systemd.services."serial-getty@ttyS0".enable = true;
  boot.kernelParams = [ "console=ttyS0" ];

  security.rngd.enable = false;

  system.autoUpgrade.enable = true;

  services.taskserver.enable = true;
  services.taskserver.fqdn = builtins.readFile ./private/taskserver-fqdn.txt;
  services.taskserver.listenHost = "::";
  services.taskserver.organisations.snente.users = [ "snowball" "ente" ];

  services.fstrim.enable = true;

  services.openvpn.servers = let
    makeVpn= name: { keyName ? null, subnet, port, useTcp ? false, ... }: {
      config = ''
        dev vpn_${name}
        dev-type tun
        ifconfig 192.168.${toString subnet}.1 192.168.${toString subnet}.2
        # openvpn --genkey --secret static.key
        secret /var/openvpn/${if keyName != null then keyName else name}.key
        port ${toString port}
        #local ${serverExternalIp}
        local ${upstreamIP}
        comp-lzo
        keepalive 300 600
        ping-timer-rem      # only for davides and jolla
        persist-tun         # not for tcp
        persist-key         # not for tcp
        cipher aes-256-cbc  # for android-udp
        ${lib.optionalString useTcp "proto tcp-server"}

        user  nobody
        group nogroup
      '';
    };
  in lib.attrsets.mapAttrs makeVpn {
    android-udp = { subnet = 88; port = ports.openvpn-android-tcp.port; keyName = "android"; };
    android-tcp = { subnet = 89; port = ports.openvpn-android-udp.port; keyName = "android"; useTcp = true; };
    #jolla      = { subnet = 90; port = 446; };  # not used anymore
    davides     = { subnet = 87; port = ports.openvpn-davides.port; };
  };

  networking.firewall.allowedPorts.openvpn-android-tcp = 444;
  networking.firewall.allowedPorts.openvpn-android-udp = { type = "udp"; port = 444; };
  networking.firewall.allowedPorts.openvpn-davides     = { type = "udp"; port = 450; };

  services.tinc.networks.bbbsnowball = {
    name = "sonline";
    hosts = {<redacted>};
    listenAddress = upstreamIP;
    package = pkgs.tinc;  # the other nodes use stable so no need to use the pre-release
    interfaceType = "tap";  # must be consistent across the network
    chroot = true; #TODO could be a problem for scripts
    extraConfig = ''
      AddressFamily=ipv4
      Mode=switch
      LocalDiscovery=no
    '';
  };

  services.tinc.networks.door = {
    name = "sonline";
    hosts = {
      door = <redacted>;
    };
    listenAddress = upstreamIP;
    package = pkgs.tinc;  # the other nodes use stable so no need to use the pre-release
    interfaceType = "tap";  # must be consistent across the network
    chroot = true; #TODO could be a problem for scripts
    extraConfig = ''
      AddressFamily=ipv4
      Mode=switch
      LocalDiscovery=no
      Port=656

      ClampMSS=yes
      IndirectData=yes
    '';
  };

  networking.firewall.allowedPorts.tinc-tcp = { port = 655; type = "tcp"; };  # default port
  networking.firewall.allowedPorts.tinc-udp = { port = 655; type = "udp"; };  # default port
  networking.firewall.allowedPorts.tinc-tcp-door = { port = 656; type = "tcp"; };
  networking.firewall.allowedPorts.tinc-udp-door = { port = 656; type = "udp"; };

  # I want persistent tinc keys even in case of a complete rebuild.
  systemd.services."tinc.bbbsnowball".preStart = lib.mkBefore ''
    mkdir -p mkdir -p /etc/tinc/bbbsnowball
    ( umask 077; cp -u /etc/nixos/secrets/tinc-bbbsnowball-rsa_key.priv /etc/tinc/bbbsnowball/rsa_key.priv )
  '';
  systemd.services."tinc.door".preStart = lib.mkBefore ''
    mkdir -p mkdir -p /etc/tinc/door
    ( umask 077; cp -u /etc/nixos/secrets/tinc-door-rsa_key.priv /etc/tinc/door/rsa_key.priv )
  '';

  containers.mate = {
    config = { config, pkgs, ... }: let
      node = pkgs.nodejs-8_x;
    in {
      imports = [ myDefaultConfig opensshWithUnixDomainSocket ];


      environment.systemPackages = with pkgs; [
        node npm2nix cacert
        #node2nix
	sqlite
      ];

      users.users.strichliste = {
        isNormalUser = true;
        extraGroups = [ ];
        openssh.authorizedKeys.keys = ssh_keys;
      };

      systemd.services.strichliste = {
        description = "Strichliste API";
        serviceConfig = {
          User = "strichliste";
          Group = "users";
          ExecStart = "${node}/bin/node server.js";
          WorkingDirectory = "/home/strichliste/strichliste";
          KillMode = "process";
        };
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" "fs.target" ];
      };

      systemd.services.pizzaimap = {
        description = "Retrieve emails with orders and make them available for the web client";
        serviceConfig = {
          User = "strichliste";
          Group = "users";
          ExecStart = "${node}/bin/node --harmony pizzaimap.js";
          WorkingDirectory = "/home/strichliste/pizzaimap";
          KillMode = "process";
          # must define PIZZA_PASSWORD
          EnvironmentFile = "/root/pizzaimap.vars";

          RestartSec = "10";
          Restart = "always";
        };
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" "fs.target" ];
      };

      services.httpd = {
        enable = true;
        adminAddr = "postmaster@${builtins.readFile ./private/w-domain.txt}";
        documentRoot = "/var/www/html";
        enableSSL = false;
        #port = 8081;
        listen = [{port = ports.strichliste-apache.port;}];
        extraConfig = ''
          #RewriteEngine on

          ProxyPass        /strich-api  http://localhost:${toString ports.strichliste-node.port}
          ProxyPassReverse /strich-api  http://localhost:${toString ports.strichliste-node.port}

          ProxyPass        /recent-orders.txt  http://localhost:${toString ports.pizzaimap.port}/recent-orders.txt
          ProxyPassReverse /recent-orders.txt  http://localhost:${toString ports.pizzaimap.port}/recent-orders.txt
        '';
      };
    };
  };

  networking.firewall.allowedPorts.strichliste-apache = 8081;
  networking.firewall.allowedPorts.strichliste-node   = 8080;  # fixed in server config
  networking.firewall.allowedPorts.pizzaimap          = 1237;  # fixed in source

  containers.feg = {
    config = { config, pkgs, ... }: let
      acmeDir = "/var/acme";
      fqdns = [
        #"${builtins.readFile ./private/feg-svn-test-domain.txt}"
        "${builtins.readFile ./private/feg-svn-domain.txt}"
      ];
      mainSSLKey = "${acmeDir}/keys/${builtins.readFile ./private/feg-svn-domain.txt}";
    in {
      imports = [ myDefaultConfig opensshWithUnixDomainSocket ];

      environment.systemPackages = with pkgs; [
        #subversion lzop libapache2-mod-svn apache2-utils apache2 curl socat knot knot-dnsutils
        subversion apacheHttpd
      ];

      nixpkgs.overlays = [ (self: super: {
        subversion = super.subversion.override {
           httpServer = true;
        };
      } )];

      services.httpd = {
        enable = true;
        adminAddr = "postmaster@${builtins.readFile ./private/w-domain.txt}";
        documentRoot = "/var/www/html";
        listen = [{port = ports.feg-svn-https.port;}];

        extraModules = ["dav" { name = "dav_svn"; path = "${pkgs.subversion}/modules/mod_dav_svn.so"; }];

        enableSSL = true;
        sslServerKey = "${mainSSLKey}/key.pem";
        sslServerCert = "${mainSSLKey}/fullchain.pem";
        extraConfig =
          ''
            Header always set Strict-Transport-Security "max-age=15552000"
            SSLProtocol All -SSLv2 -SSLv3
            SSLCipherSuite HIGH:!aNULL:!MD5:!EXP
            SSLHonorCipherOrder on


            <Location /svn>
              DAV svn

              #SVNPath /var/lib/svn  # one repo
              # multiple repos
              SVNParentPath /var/svn

              AuthType Basic
              AuthName "Subversion Repository"
              AuthUserFile /var/svn-auth/dav_svn.passwd

              # authentication is required for reading and writing
              Require valid-user

              # To enable authorization via mod_authz_svn (enable that module separately):
              #<IfModule mod_authz_svn.c>
              #AuthzSVNAccessFile /etc/apache2/dav_svn.authz
              #</IfModule>

              # The following three lines allow anonymous read, but make
              # committers authenticate themselves.  It requires the 'authz_user'
              # module (enable it with 'a2enmod').
              #<LimitExcept GET PROPFIND OPTIONS REPORT>
                #Require valid-user
              #</LimitExcept>
            </Location>
          '';

        virtualHosts = [
          # ACME challenges are forwarded to use by mailinabox, see /etc/nginx/conf.d/01_feg.conf
          {
            listen = [{ port = ports.feg-svn-acme.port;}];
            enableSSL = false;
            documentRoot = "${acmeDir}/www";
          }
        ];
      };

      users.users.acme = {
        isSystemUser = true;
        extraGroups = [ "wwwrun" ];
        home = acmeDir;
      };

      #security.acme.production = false;  # for debugging
      security.acme.directory = "${acmeDir}/keys";
      security.acme.certs = (lib.attrsets.genAttrs fqdns (fqdn: {
        email = builtins.readFile ./private/acme-email-feg.txt;
        webroot = "${acmeDir}/www";
        postRun = "systemctl reload httpd.service";
        #allowKeysForGroup = true;
        user = "acme";
        group = "wwwrun";
      }));

      # acme.nix does this for nginx and lighttpd but not apache
     systemd.services.httpd.after = [ "acme-selfsigned-certificates.target" ];
     systemd.services.httpd.wants = [ "acme-selfsigned-certificates.target" "acme-certificates.target" ];

      system.activationScripts.initAcme = lib.stringAfter ["users" "groups"] ''
        # create www root
        mkdir -m 0750 -p /var/www/html
        chown root:wwwrun /var/www/html
        if [ ! -e /var/www/html/index.html ] ; then
          echo "nothing to see here" >/var/www/html/index.html
        fi

        # more restrictive rights than the default for ACME directory
        mkdir -m 0550 -p ${acmeDir}
        chown -R acme:wwwrun ${acmeDir}
      '';

      system.activationScripts.initSvn = lib.stringAfter ["users" "groups" "wrappers"] ''
        mkdir -m 0770 -p /var/svn
        chown wwwrun:wwwrun /var/svn
        if ! ls -d /var/svn/*/ >/dev/null ; then
          # create dummy SVN so Apache doesn't fail to start
          ${pkgs.su}/bin/su wwwrun -s "${pkgs.bash}/bin/bash" -c "${pkgs.subversion}/bin/svnadmin create /var/svn/dummy"
        fi

        mkdir -m 0550 -p /var/svn-auth
        chown root:wwwrun /var/svn-auth
        if [ ! -e /var/svn-auth/dav_svn.passwd ] ; then
          touch /var/svn-auth/dav_svn.passwd
        fi
      '';
    };
  };

  networking.firewall.allowedPorts.feg-svn-https = 3000;
  networking.firewall.allowedPorts.feg-svn-acme  = 3001;

  containers.notes = {
    config = { config, pkgs, ... }: let
    in {
      imports = [ myDefaultConfig opensshWithUnixDomainSocket ];

      environment.systemPackages = with pkgs; [
        magpie magpiePython gcc stdenv gnused git socat
      ];

      nixpkgs.overlays = [ (self: super: {
        #TODO Install Python libraries to system, use overridePythonAttrs to adjust version (see esphome)
        magpiePython = self.python27.withPackages (ps: with ps; [
          setuptools pip virtualenv
        ]);
        magpie = self.fetchFromGitHub {
          owner = "BBBSnowball";
          repo  = "magpie";
          rev   = "e9dec30f4db96f26f90a07a0b8e31410d194a273"; # branch no-external-servers
          sha256 = "1kx4mq39kdfcm29p0bk5xg82gmgj0dl7kab6h77m4635bkdq6m81";
        };
        buildMagpieEnv = with self; self.writeShellScriptBin "buildMagpieEnv" ''
          out=~/magpie-env
          if [ ! -d $out ] ; then ${magpiePython}/bin/virtualenv -p ${magpiePython}/bin/python $out ; fi
          source $out/bin/activate
          pip install -r $magpie/requirements.txt
          ${gnused}/bin/sed -i 's#libname = ctypes.util.find_library.*#libname = \"${file}/lib/libmagic${stdenv.hostPlatform.extensions.sharedLibrary}\"#' $out/lib/python2.7/site-packages/magic/api.py
          # workaround: setuptools writes the egg file to the local directory
          cp -r ${magpie} /tmp/magpie
          chmod -R +w /tmp/magpie
          cd /tmp/magpie && python setup.py install
          # static dir is not installed, for some reason
          cp -r /tmp/magpie/magpie/static $out/lib/python2.7/site-packages/magpie-0.1.0-py2.7.egg/magpie/
          rm -rf /tmp/magpie
        '';
        magpieWebConfig = self.writeText "web.cfg" ''
          address='localhost'
          autosave=False
          autosave_interval=5
          port=${toString ports.notes-magpie.port}
          pwdhash=${"''"}
          repo='/home/magpie/notes'
          testing=False
          theme='/magpie/static/css/bootstrap.min.css'
          username=${"''"}
          wysiwyg=False
          prefix='/magpie/'
        '';
        initMagpieScript = self.writeShellScriptBin "initMagpie" ''
          mkdir -p ~/.magpie
          cp ${self.magpieWebConfig} ~/.magpie/web.cfg
          
          ${self.buildMagpieEnv}/bin/buildMagpieEnv

          #NOTE We may have to create ~magpie/notes for a new setup but I'm going to
          #     copy the data from the old systemd.
        '';
      } )];

      users.users.magpie = {
        isNormalUser = true;
        extraGroups = [ ];
      };

      system.activationScripts.magpie = lib.stringAfter ["users" "groups"] ''
        # make virtualenv for magpie
        ${pkgs.su}/bin/su magpie -c "${pkgs.initMagpieScript}/bin/initMagpie"
      '';

      systemd.services.magpie = {
        description = "Magpie (Notes)";
        serviceConfig = {
          User = "magpie";
          Group = "users";
          ExecStart = "${pkgs.bash}/bin/bash -c '. ~/magpie-env/bin/activate && magpie'";
          WorkingDirectory = "/home/magpie";
          KillMode = "process";

          RestartSec = "10";
          Restart = "always";
        };
        path = with pkgs; [ git magpiePython ];
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" "fs.target" ];
      };

      # I'm too lazy to change the Magpie service to listen not only on lo
      # or how to successfully DNAT to localhost. Therefore, I'm using socat
      # to bridge the gap.
      #FIXME I should find a proper solution for this.
      systemd.services.magpie-socat = {
        description = "Forward to Magpie";
        serviceConfig = {
          User = "magpie";
          Group = "users";
          ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:${toString ports.notes-magpie-ext.port},fork TCP-CONNECT:127.0.0.1:${toString ports.notes-magpie.port}";
          RestartSec = "10";
          Restart = "always";
        };
        wantedBy = [ "multi-user.target" ];
        after = [ "magpie" ];
      };
    };
  };

  networking.firewall.allowedPorts.notes-magpie  = 8082;
  networking.firewall.allowedPorts.notes-magpie-ext = 8083;

  containers.rss = {
    config = { config, pkgs, ... }: let
      poolName = "my_selfoss_pool";
      phpfpmSocketName = "/run/phpfpm/${poolName}.sock";
    in {
      imports = [ myDefaultConfig opensshWithUnixDomainSocket ];

      environment.systemPackages = with pkgs; [
      ];

      services.nginx = {
        enable = true;
        virtualHosts.rss = {
          listen = [ { addr = "0.0.0.0"; port = ports.rss.port; extraParameters = [ "default_server" ]; } ];
          root = "/var/www/html";

          locations."/favicon.ico" = {
            root = "/var/lib/selfoss/public";
          };
          locations."/selfoss" = {
            root = "/var/lib/selfoss";
            extraConfig = ''
              # similar to nixos/modules/services/mail/roundcube.nix - well, not so similar anymore
              location ~ ^/selfoss/php/(.*)$ {
                alias /var/lib/selfoss/index.php?$1;
                fastcgi_pass unix:/run/phpfpm/my_selfoss_pool.sock;
            
                # We could include ${pkgs.nginx}/conf/fastcgi_params but we need a different
                # SCRIPT_FILENAME, SCRIPT_NAME and REQUEST_URI.

                fastcgi_param SCRIPT_FILENAME /var/lib/selfoss/index.php;                                                                                     
                fastcgi_param SCRIPT_NAME /selfoss/index.php;
                fastcgi_param REQUEST_URI        /selfoss/$1;

                fastcgi_param  QUERY_STRING       $query_string;
                fastcgi_param  REQUEST_METHOD     $request_method;
                fastcgi_param  CONTENT_TYPE       $content_type;
                fastcgi_param  CONTENT_LENGTH     $content_length;

                #fastcgi_param  REQUEST_URI        $request_uri;
                fastcgi_param  DOCUMENT_URI       $document_uri;
                fastcgi_param  DOCUMENT_ROOT      $document_root;
                fastcgi_param  SERVER_PROTOCOL    $server_protocol;
                fastcgi_param  REQUEST_SCHEME     $scheme;
                fastcgi_param  HTTPS              $https if_not_empty;

                fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
                fastcgi_param  SERVER_SOFTWARE    nginx/$nginx_version;                                                                                       

                fastcgi_param  REMOTE_ADDR        $remote_addr;
                fastcgi_param  REMOTE_PORT        $remote_port;
                fastcgi_param  SERVER_ADDR        $server_addr;
                fastcgi_param  SERVER_PORT        $server_port;
                fastcgi_param  SERVER_NAME        $server_name;

                # PHP only, required if PHP was built with --enable-force-cgi-redirect
                fastcgi_param  REDIRECT_STATUS    200;
              }

              # see https://github.com/SSilence/selfoss/wiki/nginx-configuration

              # regex matches win so make this a regex match
              location ~ ^/selfoss/favicons/(.*)$   { alias /var/lib/selfoss/data/favicons/$1; }                                                                     
              location ~ ^/selfoss/thumbnails/(.*)$ { alias /var/lib/selfoss/data/thumbnails/$1; }                                                                   

              location ~ ^/selfoss/public/(.*)$     { alias /var/lib/selfoss/public/$1; }

              location ~ ^/selfoss/(.*)$ {
                try_files /public/$1 /selfoss/php/$1$is_args$args;
              }
            '';
          };
        };
      };

      services.selfoss = {
        enable = true;
        database.type = "sqlite";
        extraConfig = ''
          salt=22lkjl1289asdf099s8f
          items_perpage=50
          rss_max_items=3000
          homepage=unread
          base_url=/selfoss/
          ; hide share buttons
          share=
          items_lifetime=100
          ; quick 'n' dirty fix for only marking some items read:
          items_perpage=20
          auto_stream_more=0
          ; php-fpm has catch_workers_output=1 and it logs to syslog
          logger_destination=file:php://stderr
        '';
        pool = "${poolName}";
      };

      # custom pool because the default one has an excess of workers 
      services.phpfpm.poolConfigs."${poolName}" = ''
        listen = "${phpfpmSocketName}";
        listen.owner = nginx
        listen.group = nginx
        listen.mode = 0600
        user = nginx
        pm = dynamic
        pm.max_children = 30
        pm.start_servers = 5
        pm.min_spare_servers = 2
        pm.max_spare_servers = 5
        pm.max_requests = 500
        catch_workers_output = 1
      '';

      system.activationScripts.wwwroot = lib.stringAfter ["users" "groups"] ''
        # create www root
        mkdir -m 0750 -p /var/www/html
        chown root:nginx /var/www/html
        if [ ! -e /var/www/html/index.html ] ; then
          echo "nothing to see here" >/var/www/html/index.html
        fi

        #NOTE This does *not* work because selfoss-config makes it world-readable again :-(
        # world-readable data directory is not a good idea!
        chmod o-rwx /var/lib/selfoss/data
        # in fact, no reason for selfoss to be world-readable, as well
        chmod o-rwx /var/lib/selfoss
        #echo "BLUB: $SYSTEM_CONFIG, $systemConfig"
        #ls -ld /var/lib/selfoss
      '';
    };
  };

  networking.firewall.allowedPorts.rss  = 8084;


  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "19.03"; # Did you read the comment?

}
