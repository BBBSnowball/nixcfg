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

in {
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
      myDefaultConfig
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

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 8081 8080 1237 3000 3001 ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  networking.interfaces.ens3.ipv4.addresses = [ {
    address = "192.168.84.133";
    prefixLength = 24;
  } ];
  networking.useDHCP = false;

  networking.defaultGateway = "192.168.84.128";
  networking.nameservers = [ "62.210.16.6" "62.210.16.7" ];

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
        listen = [{port = 8081;}];
        extraConfig = ''
          #RewriteEngine on

          ProxyPass        /strich-api  http://localhost:8080
          ProxyPassReverse /strich-api  http://localhost:8080

          ProxyPass        /recent-orders.txt  http://localhost:1237/recent-orders.txt
          ProxyPassReverse /recent-orders.txt  http://localhost:1237/recent-orders.txt
        '';
      };
    };
  };

  containers.feg = {
    config = { config, pkgs, ... }: let
      acmeDir = "/var/acme";
      fqdns = [
        "${builtins.readFile ./private/feg-svn-test-domain.txt}"
        #"${builtins.readFile ./private/feg-svn-domain.txt}"
      ];
      mainSSLKey = "${acmeDir}/keys/${builtins.readFile ./private/feg-svn-test-domain.txt}";
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
        listen = [{port = 3000;}];

        enableSSL = true;
        sslServerKey = "${mainSSLKey}/key.pem";
        sslServerCert = "${mainSSLKey}/fullchain.pem";
        extraConfig =
          ''
            Header always set Strict-Transport-Security "max-age=15552000"
            SSLProtocol All -SSLv2 -SSLv3
            SSLCipherSuite HIGH:!aNULL:!MD5:!EXP
            SSLHonorCipherOrder on

            #Alias "/.well-known/acme-challenge" "${acmeDir}/www/.well-known/acme-challenge"
          '';
        #extraConfig = ''''; #TODO

        virtualHosts = [
          # ACME challenges are forwarded to use by mailinabox, see /etc/nginx/conf.d/01_feg.conf
          {
            listen = [{ port = 3001;}];
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

      system.activationScripts.initAcme = ''
        # create www root and directories for acme client
        mkdir -m 0750 -p /var/www/html
        chown root:wwwrun /var/www/html
        #mkdir -m 0750 -p ${acmeDir}/keys ${acmeDir}/www
        #chown -R acme:wwwrun ${acmeDir}
        # more restrictive rights than the default for ACME directory
        mkdir -m 0550 -p ${acmeDir}
        chown -R acme:wwwrun ${acmeDir}

        # create dummy keys
        # see https://github.com/NixOS/nixos-org-configurations/blob/master/nixos-org/webserver.nix
        #FIXME Is this necessary? Can we use security.acme.preliminarySelfsigned instead?
        #for fqdn in ${lib.strings.concatStringsSep " " fqdns} ; do
        #  dir=~acme/keys/$fqdn
        #  if [ ! -e $dir/key.pem ] ; then
        #    echo "Creating dummy keys for $fqdn..."
        #    mkdir -m 0750 -p $dir
        #    ${pkgs.openssl}/bin/openssl genrsa -passout pass:foo -des3 -out $dir/key-in.pem 1024
        #    ${pkgs.openssl}/bin/openssl req -passin pass:foo -new -key $dir/key-in.pem -out $dir/key.csr \
        #      -subj "/C=NL/ST=Denial/L=Springfield/O=Dis/CN=www.example.com"
        #    ${pkgs.openssl}/bin/openssl rsa -passin pass:foo -in $dir/key-in.pem -out $dir/key.pem
        #    ${pkgs.openssl}/bin/openssl x509 -req -days 365 -in $dir/key.csr -signkey $dir/key.pem -out $dir/fullchain.pem
        #    chown -R acme:wwwrun $dir
        #  fi
        #done
      '';
    };
  };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "19.03"; # Did you read the comment?

}
