{ config, lib, modules, ... }:
let
  ports = config.networking.firewall.allowedPorts;
in {
  containers.feg = {
    autoStart = true;
    config = { config, pkgs, ... }: let
      acmeDir = "/var/lib/acme";
      fqdns = [
        #"${builtins.readFile ./private/feg-svn-test-domain.txt}"
        "${builtins.readFile ./private/feg-svn-domain.txt}"
      ];
      mainSSLKey = "${acmeDir}/${builtins.readFile ./private/feg-svn-domain.txt}";
    in {
      imports = [ modules.container-common ];

      environment.systemPackages = with pkgs; [
        #subversion lzop libapache2-mod-svn apache2-utils apache2 curl socat knot knot-dnsutils
        subversion apacheHttpd
      ];

      services.httpd = {
        enable = true;
        adminAddr = "postmaster@${builtins.readFile ./private/w-domain.txt}";

        extraModules = ["dav" { name = "dav_svn"; path = "${pkgs.apacheHttpdPackages.subversion}/modules/mod_dav_svn.so"; }];
      };

      services.httpd.virtualHosts.default = {
        documentRoot = "/var/www/html";
        listen = [{ port = ports.feg-svn-https.port; ssl = true; }];

        sslServerKey = "${mainSSLKey}/key.pem";
        sslServerCert = "${mainSSLKey}/fullchain.pem";
        extraConfig =
          ''
            Header always set Strict-Transport-Security "max-age=15552000"
            # also set by NixOS
            #SSLProtocol All -SSLv2 -SSLv3
            #SSLCipherSuite HIGH:!aNULL:!MD5:!EXP
            #SSLHonorCipherOrder on


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
      };

      services.httpd.virtualHosts.acme = {
        # ACME challenges are forwarded to use by mailinabox, see /etc/nginx/conf.d/01_feg.conf
        listen = [{ port = ports.feg-svn-acme.port; ssl = false; }];
        documentRoot = "${acmeDir}/www";
      };

      users.users.acme = {
        isSystemUser = true;
        extraGroups = [ "wwwrun" ];
        home = acmeDir;
      };

      #security.acme.production = false;  # for debugging
      security.acme.certs = (lib.attrsets.genAttrs fqdns (fqdn: {
        email = builtins.readFile ./private/acme-email-feg.txt;
        webroot = "${acmeDir}/www";
        postRun = "systemctl reload httpd.service";
        #allowKeysForGroup = true;
        #user = "acme";
        group = "wwwrun";
      }));
      security.acme.acceptTerms = true;

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
        #NOTE This is probably not true anymore for NixOS 19.09.
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
}
