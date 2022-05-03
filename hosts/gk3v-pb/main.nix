{ config, pkgs, lib, rockpro64Config, routeromen, withFlakeInputs, private, ... }@args:
let                                                                                                 
  modules = args.modules or (import ./modules.nix {});
  hostSpecificValue = path: import "${private}/by-host/${config.networking.hostName}${path}";
in
{
  imports =
    with routeromen.nixosModules; [
      snowball-headless-big
      raspi-zero-usbboot
      raspi-pico
      network-manager
      desktop-base
      tinc-client
    ] ++
    [ ./hardware-configuration.nix
      ./rust.nix
      ./udev.nix
      ./3dprint.nix
      ./xrdp.nix
      ./brother_ql_service.nix
    ];

  disabledModules = [ "services/networking/xrdp.nix" ];

  networking.hostName = "gk3v-pb";

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;    
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  networking.useDHCP = false;

  networking.interfaces."tinc.bbbsnowbal".ipv4.addresses = [ {
    address = "192.168.84.55";
    prefixLength = 24;
  } ];

  users.users.user = {
    isNormalUser = true;
    passwordFile = "/etc/nixos/secret/rootpw";
    # lp: I couldn't get the Brother QL-500 to work through cups and the
    # web interface can only do text so we have to access it directly.
    extraGroups = [ "dialout" "wheel" "lp" ];
    openssh.authorizedKeys.keyFiles = [ "${private}/ssh-laptop.pub" ];

    packages = with pkgs; [
      # GraphViz is used for dependency tree in FreeCAD.
      cura freecad kicad graphviz blender
      firefox pavucontrol chromium
      mplayer mpv vlc
      speedcrunch
      libreoffice gimp
      gnome.eog gnome.evince
      x11vnc
      (python3Packages.brother-ql)
      #vscodium
      vscode  # We need MS C++ Extension for PlatformIO.
      python3 # for PlatformIO
      #platformio  # would be a different version than that in VS Code
      w3m
      kupfer
      (git.override { guiSupport = true; })
      gnome.gnome-screenshot
    ];
  };
  users.users.root = {
    # generate contents with `mkpasswd -m sha-512`
    passwordFile = "/etc/nixos/secret/rootpw";

    openssh.authorizedKeys.keyFiles = [ "${private}/ssh-laptop.pub" ];
  };

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "vscode"
  ];

  environment.interactiveShellInit = ''
    # works for AVR and ESP32-C3
    alias pioFix='nix-shell -p autoPatchelfHook -p udev -p zlib -p ncurses5 -p expat -p mpfr -p libftdi -p libusb1 -p hidapi -p libusb-compat-0_1 -p xorg.libxcb -p freetype -p fontconfig -p python2 --run "patchShebangs /home/user/.platformio/packages/tool-avrdude/avrdude && autoPatchelf ~/.platformio/packages/ ~/.vscode/extensions"'
    alias fixPlatformIO=pioFix
  '';

  services.xrdp.enable = true;
  services.xrdp.extraConfig = ''
    [ExistingVNC]
    name=Existing VNC
    lib=libvnc.so
    port=ask5900
    username=na
    password=ask
    ip=127.0.0.1
  '';
  networking.firewall.allowedTCPPorts = [ config.services.xrdp.port ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    telnet
    #nix-output-monitor
    mbuffer brotli zopfli
    tree
  ];

  networking.firewall.allowedUDPPortRanges = [ { from = 60000; to = 61000; } ];

  nix.registry.routeromen.flake = routeromen;

  # desktop stuff
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;

  # Brother P-Touch QL-500
  services.printing.drivers = let
    #NOTE This doesn't work, yet. The print data is processed but the printer doesn't print it.
    # must be 32-bit for patchelf of rastertobrpt1
    ql500 = pkgs.callPackage_i686 ({ stdenv, autoPatchelfHook, fetchurl, makeWrapper }:
    stdenv.mkDerivation {
      pname = "ql500";
      version = "13.08.2013";

      src = fetchurl {
        #NOTE unfree, requires EULA
        url = "https://download.brother.com/welcome/dlfp002255/cupswrapper-ql550-src-1.1.1-1.tar.gz";
        sha256 = "sha256-hDm12quydUhp8dTXpf7SVqUmbV9NDTmbrLa/Kh+/fK0=";
      };
      filterSrc = fetchurl {
        #NOTE unfree, requires EULA
        url = "https://download.brother.com/welcome/dlfp002168/ql550lpr-1.0.1-0.i386.deb";
        sha256 = "sha256-dBlk+FIVodUr/6kEst9LW+UTKTOoJi+RnDVZ72QFh+w=";
      };
      templateSrc = fetchurl {
        #NOTE unfree, requires EULA
        url = "https://download.brother.com/welcome/dlfp100382/templateql500.tar.gz";
        sha256 = "sha256-smsnNR+wJzXNTMWtnZnk808hoDqZder2WQFydbJFHJk=";
      };

      printer_model = "ql550";
      device_model  = "PTouch";

      nativeBuildInputs = [ makeWrapper autoPatchelfHook ];

      postUnpack = ''
        ar x $filterSrc
        tar -xf data.tar.gz
      '';
      postPatch = ''
        substituteInPlace cupswrapper/cupswrapperql550pt1 \
          --replace /usr/lib/cups/ $out/lib/cups/ \
          --replace /usr/lib64/cups/ $out/lib/cups/ \
          --replace /usr/share/cups/model $out/share/cups/model \
          --replace '/opt/brother/''${device_model}/''${printer_model}' $out/'lib/''${device_model}/''${printer_model}'
        substituteInPlace ../opt/brother/$device_model/$printer_model/lpd/filter$printer_model \
          --replace /opt/brother/$device_model/ $out/lib/$device_model/ \
          --replace /usr/bin/pstops pstops
        substituteInPlace ../opt/brother/$device_model/$printer_model/inf/setupPrintcappt1 \
          --replace /opt/brother/$device_model/ $out/lib/$device_model/
      '';
      buildPhase = ''
        ( cd brcupsconfig && make all )
      '';
      installPhase = ''
        mkdir -p $out/lib/cups/filter $out/share/cups/model
        cp ../opt/brother/$device_model -r $out/lib/$device_model
        sh ./cupswrapper/cupswrapperql550pt1 -i

        #lpdfile=$out/lib/$device_model/$printer_model/lpd/filter$printer_model
        lpdfile=$out/lib/cups/filter/brother_lpdwrapper_$printer_model
        substituteInPlace $lpdfile \
          --replace /usr/bin/psnup psnup
          #--replace /bin/sh "/bin/sh -x"
          #--replace DEBUG=0 DEBUG=8
        wrapProgram $lpdfile --prefix PATH : ${with pkgs; lib.makeBinPath [ which gnugrep gnused coreutils file a2ps psutils gawk ghostscript ]}

        if egrep -r '/opt|/usr' $out ; then
          echo "Error: Output directory contains reference to /opt or /usr!" >&2
          exit 1
        fi

        mkdir $out/example
        tar -C $out/example -xzf $templateSrc

        mkdir $out/lib/$device_model/$printer_model/cupswrapper
        #cp brcupsconfig/brcupsconfpt1 $out/lib/$device_model/$printer_model/cupswrapper/brcupsconfpt1
      '';

      #NOTE Manual step after creating the printer in Cups: lpadmin -p "Brother_QL-500" -o pdftops-renderer-default=gs

      meta.homepage = "https://support.brother.com/g/b/downloadlist.aspx?c=de&lang=de&prod=lpql550euk_same&os=130&flang=English";
    }) {};

    foomatic-db-engine = with pkgs; stdenv.mkDerivation {
      pname = "foomatic-db-engine";
      version = "20200131-git";
      src = fetchFromGitHub {
        owner = "OpenPrinting";
        repo = "foomatic-db-engine";
        rev = "068c92311018a75c621c57328845b439d789bf50";
        sha256 = "sha256-5xSpGOpcOWmKdCm3wNoLdL7cZWzi+hjOVYfhEYe5P7E=";
      };
      nativeBuildInputs = [ autoconf automake perl perlPackages.XMLLibXML perlPackages.DBI perlPackages.Clone file which ];
      propagatedBuildInputs = [ perl perlPackages.XMLLibXML perlPackages.DBI perlPackages.Clone ];
      
      postPatch = ''
        #ls -l
        #patchShebangs --build makeDefaults.in
        #patchShebangs --build .
        substituteInPlace configure.ac \
          --replace BINSEARCHPATH=/usr/bin:/bin:/usr/local/bin BINSEARCHPATH="$PATH"
        ./make_configure
      '';
      preConfigure = ''
        export FILEUTIL=$file/bin/file
        #export PERLPREFIX=$out
        export PERLPREFIX=/
        #configureFlags=( "--sysconfdir=$out/etc" )
      '';
      makeFlags = [ "DESTDIR=$(out)" ];
      postInstall = ''
        mv $out/nix/store/*/* $out/
        rm -rf $out/nix/store/
      '';
    };

    ql500b = with pkgs; stdenv.mkDerivation {
      pname = "printer-driver-ptouch";
      version = "1.6";
      src = fetchFromGitHub {
        owner = "philpem";
        repo = "printer-driver-ptouch";
        rev = "v1.6";
        sha256 = "sha256-s1l25PsnUwvZljLEZbuRpwC8n9Vzu1b+mhyTbJmdkLA=";
      };
      buildInputs = [ cups libpng ];
      nativeBuildInputs = [ autoconf automake perl perlPackages.XMLLibXML foomatic-db-engine ];
      postPatch = ''
        ./autogen.sh
        patchShebangs foomaticalize
      '';
      postInstall = ''
        # Pre-build PPD files
        # from https://salsa.debian.org/printing-team/ptouch-driver/-/blob/bc349600f9925cb87f478fa655153f85a72809f0/debian/rules#L28
        # and https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=printer-driver-ptouch#n38
        #mkdir foomatic-db
	#cp -r $out/share/foomatic/* foomatic-db/
	#echo '#' > foomatic-db/db/oldprinterids
	mkdir -p $out/share/ppd
        FOOMATICDB=$out/share/foomatic foomatic-compiledb -j $NIX_BUILD_CORES -t ppd -d $out/share/ppd/ptouch-driver
        #`ls -1 ./foomatic-db/db/source/driver/*ptouch*.xml | perl -p -e 's:^.*db/source/driver/(\S*)\.xml\s*$$:\1\n:'`


      '';
    };
  in [ ql500b ];

  services.printing.extraConf = "LogLevel debug2";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?
}
