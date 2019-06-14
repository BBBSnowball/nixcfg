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
    prefixLength = 24;
  } ];
  networking.useDHCP = false;

  networking.defaultGateway = "192.168.84.128";
  networking.nameservers = [ "62.210.16.6" "62.210.16.7" ];


  networking.firewall.enable = true;

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
    serverExternalIp = <redacted>;
    makeVpn= name: { keyName ? null, subnet, port, useTcp ? false, ... }: {
      config = ''
        dev vpn_${name}
        dev-type tun
        ifconfig 192.168.${toString subnet}.1 192.168.${toString subnet}.2
        # openvpn --genkey --secret static.key
        secret /var/openvpn/${if keyName != null then keyName else name}.key
        port ${toString port}
        #local ${serverExternalIp}
        local 192.168.84.133
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

  containers.mate = {
    config = { config, pkgs, ... }: let
      node = pkgs.nodejs-8_x;
    in {
      imports = [ myDefaultConfig opensshWithUnixDomainSocket ];


      environment.systemPackages = with pkgs; [
        node npm2nix cacert
        #node2nix
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
        echo "nothing to see here" >/var/www/html/index.html

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
        python27 virtualenv pip
      ];

      nixpkgs.overlays = [ (self: super: {
        virtualenv = self.python27Packages.virtualenv;
        pip        = self.python27Packages.pip;
        magpie = self.fetchFromGitHub {
          owner = "BBBSnowball";
          repo  = "magpie";
          rev   = "e9dec30f4db96f26f90a07a0b8e31410d194a273"; # branch no-external-servers
          sha256 = "1kx4mq39kdfcm29p0bk5xg82gmgj0dl7kab6h77m4635bkdq6m81";
        };
        #initMagpieScript = self.pkgs.writeShellScript "initMagpie" ''  # writeShellScript is not available for some reason
        initMagpieScript = self.pkgs.writeShellScriptBin "initMagpie" ''
          #FIXME We could put those into Nix store without too much effort.
          if [ ! -e ~/magpie-env ] ; then ${self.virtualenv}/bin/virtualenv -p python2.7 ~/magpie-env ; fi
          #if [ ! -e ~/${self.pkgs.git} clone https://github.com/BBBSnowball/magpie ~/magpie -b no-external-servers --single-branch ; fi
          source ~/magpie-env/bin/activate
          ${self.pip}/bin/pip install -r ${self.magpie}/requirements.txt
        '';
      } )];

      services.httpd = {
        enable = true;
        adminAddr = "postmaster@${builtins.readFile ./private/w-domain.txt}";
        documentRoot = "/var/www/html";
        listen = [{port = 8082;}];
      };

      users.users.magpie = {
        isNormalUser = true;
        extraGroups = [ ];
      };

      system.activationScripts.magpie = lib.stringAfter ["users" "groups"] ''
        # create www root
        mkdir -m 0750 -p /var/www/html
        chown root:wwwrun /var/www/html
        echo "nothing to see here" >/var/www/html/index.html

        # make virtualenv for magpie
        ${pkgs.su}/bin/su magpie -c "${pkgs.initMagpieScript}"
      '';
    };
  };


  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "19.03"; # Did you read the comment?

}
