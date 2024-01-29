{ config, pkgs, ... }:
let
  usedPackages = (with pkgs; [
    perl
    sqlite-interactive
    liberation_ttf
    #FIXME This won't make it available to binaries.
    libusb
    inetutils  # ifconfig
    procps     # free
  ]);
  usedPerlPackages = with pkgs.perlPackages; [
    ArchiveZip                    #    libarchive-zip-perl/oldoldstable,now 1.39-1+deb8u1 all [installed,automatic]
    ClassAccessor                 #    libclass-accessor-perl/oldoldstable,now 0.34-1 all [installed,automatic]
    commonsense                   #    libcommon-sense-perl/oldoldstable,now 3.73-2+b3 armhf [installed,automatic]
    DeviceSerialPort              # y  libdevice-serialport-perl/oldoldstable,now 1.04-3+b1 armhf [installed]
                                  #    libdpkg-perl/oldoldstable,now 1.17.27 all [installed]
    Error                         #    liberror-perl/oldoldstable,now 0.17-1.1 all [installed]
    FileCopyRecursive             #    libfile-copy-recursive-perl/oldoldstable,now 0.38-1 all [installed,automatic]
    strip-nondeterminism          #    libfile-stripnondeterminism-perl/oldoldstable,now 0.003-1 all [installed,automatic]
    GD                            #    libgd-perl/oldoldstable,now 2.53-1+b1 armhf [installed]
                                  #    libgd-svg-perl/oldoldstable,now 0.33-1 all [installed]
    GDText                        # y  libgd-text-perl/oldoldstable,now 0.86-9 all [installed]
    IOSocketSSL                   # y  libio-socket-ssl-perl/oldoldstable,now 2.002-2+deb8u3 all [installed,automatic]
    IOString                      #    libio-string-perl/oldoldstable,now 1.08-3 all [installed,automatic]
    JSON                          # y  libjson-perl/oldoldstable,now 2.61-1 all [installed]
    JSONXS                        #    libjson-xs-perl/oldoldstable,now 2.340-1+b2 armhf [installed,automatic]
    LocaleGettext                 #    liblocale-gettext-perl/oldoldstable,now 1.05-8+b1 armhf [installed]
                                  #    libnet-libidn-perl/oldoldstable,now 0.12.ds-2+b1 armhf [installed,automatic]
                                  #    libnet-ssleay-perl/oldoldstable,now 1.65-1+deb8u1 armhf [installed,automatic]
                                  #    libparse-debianchangelog-perl/oldoldstable,now 1.2.0-1.1 all [installed,automatic]
                                  #    libperl4-corelibs-perl/oldoldstable,now 0.003-1 all [installed]
    SubName                       #    libsub-name-perl/oldoldstable,now 0.12-1 armhf [installed,automatic]
                                  #    libsvg-perl/oldoldstable,now 2.59-1 all [installed,automatic]
                                  #    libtext-charwidth-perl/oldoldstable,now 0.04-7+b4 armhf [installed]
                                  #    libtext-iconv-perl/oldoldstable,now 1.7-5+b2 armhf [installed]
                                  #    libtext-wrapi18n-perl/oldoldstable,now 0.06-7 all [installed]
    TimeDate                      #    libtimedate-perl/oldoldstable,now 2.3000-2 all [installed]
    DataUUID                      #    libuuid-perl/oldoldstable,now 0.05-1+b1 armhf [installed]
                                  #    perl/oldoldstable,now 5.20.2-3+deb8u12 armhf [installed]
                                  # y  perl-base/oldoldstable,now 5.20.2-3+deb8u12 armhf [installed]
                                  #    perl-modules/oldoldstable,now 5.20.2-3+deb8u12 all [installed]
                                  # ^ wanted by fhem.deb (which was not installed - I was using fhem from sources)

                                  # Additional packages wanted for Debian:
                                  # (see https://debian.fhem.de/html/manual.html?v=6.0)
    LWP                           # libwww-perl
                                  # libcgi-pm-perl
    DBDSQLite                     # libdbd-sqlite3-perl
    TextDiff                      # libtext-diff-perl
                                  # libmail-imapclient-perl
    GDGraph                       # libgd-graph-perl
    TextCSV                       # libtext-csv-perl
    XMLLibXMLSimple               # libxml-simple-perl
    ListMoreUtils                 # liblist-moreutils-perl
                                  # libimage-librsvg-perl
    Socket6                       # libsocket6-perl
    IOSocketInet6                 # libio-socket-inet6-perl
    MIMEBase64                    # libmime-base64-perl
    ImageInfo                     # libimage-info-perl
    NetServer                     # libnet-server-perl
    DateManip                     # libdate-manip-perl
    HTMLTreeBuilderXPath          # libhtml-treebuilder-xpath-perl
    Mojolicious                   # libmojolicious-perl
    XMLLibXML                     # libxml-bare-perl
    AuthenOATH                    # libauthen-oath-perl
    ConvertBase32                 # libconvert-base32-perl
    ModulePluggable               # libmodule-pluggable-perl
                                  # libnet-bonjour-perl
    #CryptURandom                 # libcrypt-urandom-perl
  ];
  #FIXME There *must* be a better way to do this. The Wiki suggests using nix-shell. Well...
  perlDependencies = pkgs.stdenv.mkDerivation {
    pname = "fhem-dependencies";
    version = "0.1";
    src = null;
    dontUnpack = true;
    dontConfigure = true;
    paths = usedPerlPackages;
    passAsFile = [ "paths" ];
    buildInputs = [ pkgs.xorg.lndir ];
    installPhase = ''
      addIt() {
        if [ -f $1/nix-support/propagated-build-inputs ] ; then
          for x in `cat $1/nix-support/propagated-build-inputs` ; do
            addIt $x
          done
        fi
        if [ -d $1/lib/perl5/site_perl ] ; then
          lndir -silent $i $out
        fi
      }

      mkdir $out
      for i in $(cat $pathsPath); do
        addIt $i
      done
    '';
  };
  fhemSrcHashes = {
    "6.0" = "sha256-X8ldXi/r/80nDDc2JXrljVPnAEAx/gkTO7G5mqg34Q8=";
    "6.2" = "sha256-M24XCfnIqJBSYhTMPKlxOuhmS+79LTzR73hMrOFGn6Q=";
  };
  fhemPkg = pkgs.stdenv.mkDerivation rec {
    pname = "fhem";
    version = "6.2";
    src = pkgs.fetchurl {
      url = "http://fhem.de/fhem-${version}.tar.gz";
      hash = fhemSrcHashes."${version}";
    };
    patches = [ ./01-fhem--keyFile-not-in-store.patch ];
    dontBuild = true;
    installPhase = ''
      cp -r . $out
    '';
  };
in
{
  systemd.services.fhem = {
    description = "fhem home automation server";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network.target"
      #"auditd.service"
    ];
    path = usedPackages ++ [ pkgs.xorg.lndir ];
    environment.PERL5LIB="${fhemPkg}:${fhemPkg}/FHEM:$PERL5LIB:${perlDependencies}/lib/perl5/site_perl";
    environment.FHEM_MODPATH = fhemPkg;
    environment.FHEM_DATADIR = "/var/fhem/data";
    preStart = ''
      if [ -e /var/fhem/data ] ; then
        find /var/fhem/data -type l -lname "/nix/store/*" -exec rm {} \+
      fi
      lndir -silent ${fhemPkg} /var/fhem/data
    '';
    serviceConfig = {
      #Type = "forking";
      WorkingDirectory = "/var/fhem/data";
      ExecStart = "${pkgs.perl}/bin/perl ./fhem.pl fhem.cfg";
      Restart = "on-failure";
      RestartSec = "10";
    };
  };

  users.users.fhem = {
    isNormalUser = false;
    isSystemUser = true;
    createHome = true;
    home = "/var/fhem";
    group = "fhem";
  };
  users.groups.fhem = {};

  networking.firewall.interfaces.br0.allowedTCPPorts = [ 8083 8084 8085 ];

  services.shorewall.rules.fhem-web = {
    proto = "tcp";
    destPort = [ 8083 8084 8085 ];
    source = "loc,tinc:192.168.84.50";
  };

  services.udev.extraRules = ''
    # fhem needs access to CUL868 gateway but other users shouldn't accidentally use it
    KERNEL=="ttyACM*", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="204b", ATTRS{product}=="CUL868", SYMLINK+="ttyCUL868", OWNER="fhem", MODE="0600"
  '';
}
