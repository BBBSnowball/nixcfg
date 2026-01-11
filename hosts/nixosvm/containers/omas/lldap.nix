{ lib, pkgs, domain, ports, ... }:
let
  hostName = "accounts.${domain}";
  port = ports.omas-accounts.port;
  port2 = 8020;

  # some values are only needed for the first run
  initial = true;

  ldap_base_dn = "dc=omas,dc=example,dc=com";

  oldFrontend = pkgs.lldap.frontend;
  frontend = (import ./lldap-static.nix { inherit pkgs; }).frontend-static;
in
{
  services.nginx.virtualHosts.${hostName} = {
    listen = [
      { addr = "0.0.0.0"; inherit port; }
    ];
    locations."/"= {
      proxyPass = "http://localhost:${toString port2}/";
      recommendedProxySettings = true;
      proxyWebsockets = true;
      extraConfig = ''
        #proxy_ssl_trusted_certificate FIXME.cert;  #FIXME use SSL for LDAP and web interface

        # There is some inline Javascript and styles that we cannot easily replace. We are guarding against use
        # of CDN (not cross-site-scripting), so `unsafe-inline` is ok-ish here.
        add_header Content-Security-Policy "default-src 'self' 'unsafe-inline' data:; script-src 'self' 'wasm-unsafe-eval' 'unsafe-inline';";
        add_header X-Frame-Options "deny";
      '';
    };
    locations."= /favicon.ico".alias = "/var/www/html-intern/ogr-favicon-a.ico";

    # use index_local.html instead of lots of files from the cloud
    #locations."=/".alias = "${frontend}/index.html";  # -> broken...
    #locations."=/".alias = "${frontend}/";
    #locations."=/index.html".alias = "${frontend}/";
    locations."/static/".alias = "${frontend}/static/";
    # Not served with the correct MIME type for gzipped WASM, by default. Thus, let the backend handle this.
    #locations."/pkg/".alias = "${frontend}/pkg/";
  };

  services.lldap = {
    enable = true;

    # generate all secrets with:
    #   cd /etc/nixos/secret/by-host/nixosvm/omas
    #   LC_ALL=C tr -dc 'A-Za-z0-9!#%&()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 32 >lldap-jwt-secret
    #   LC_ALL=C tr -dc 'A-Za-z0-9!#%&()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 32 >lldap-admin-password
    #   ( echo -n "LLDAP_KEY_SEED="; LC_ALL=C tr -dc 'A-Za-z0-9!#%&()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 32 ) >lldap-env
    environment = {
      LLDAP_JWT_SECRET_FILE = "%d/secret_lldap-jwt-secret";
      #NOTE This will only be updated if force_ldap_user_pass_reset is set.
      LLDAP_LDAP_USER_PASS_FILE = lib.mkIf initial "%d/secret_lldap-admin-password";
    };
    environmentFile = lib.mkIf initial "/run/credstore/secret_lldap-env";
    settings = {
      ldap_user_email = "postmaster@${domain}";
      ldap_user_dn = "admin";
      ldap_port = 3890;
      ldap_host = "localhost";
      inherit ldap_base_dn;
      http_url = "https://${hostName}";
      http_port = port2;
      database_url = "postgres://%2Fvar%2Frun%2Fpostgresql/lldap";
      # We are using the key seed, so don't provide a key.
      server_key = "";

      # NextCloud tries to use nested groups.
      ignored_group_attributes = [ "memberof" ];

      #verbose = true;

      force_ldap_user_pass_reset = false;
    };
    silenceForceUserPassResetWarning = true;

    # patch lldap to use index_local.html instead of lots of files from the cloud
    #NOTE We also use Nginx to serve the static frontend but lldap will serve its
    #     index.html under many URIs (e.g. `/users`) so we also have to replace it here.
    package = let
      oldFrontend = pkgs.lldap.frontend;
      frontend = (import ./lldap-static.nix { inherit pkgs; }).frontend-static;

      #rebuild = pkgs.lldap.overrideAttrs (old: {
      #  postPatch = ''
      #    substituteInPlace server/src/infra/tcp_server.rs --subst-var-by frontend '${frontend}'
      #  '';
      #});

      dirtyReplace = pkgs.runCommand pkgs.lldap.name {
        passthru.meta = pkgs.lldap.meta;
      } ''
        cp -r ${pkgs.lldap} $out
        chmod -R +w $out
        #for x in $out/bin/* ; do
        #  substituteInPlace "$x" --replace-warn '${oldFrontend}' '${frontend}'
        #done
        sed -bi 's#${oldFrontend}#${frontend}#g' $out/bin/*
      '';
    in dirtyReplace;
  };

  systemd.services.lldap = {
    serviceConfig.LoadCredential = lib.mkMerge [
      [ "secret_lldap-jwt-secret" ]
      (lib.mkIf initial [ "secret_lldap-admin-password" ])
    ];
    after = [ "postgresql.service" ];
  };

  environment.systemPackages = [ pkgs.ldapvi ];

  environment.etc."ldap.conf".text = ''
    HOST localhost:3890
    BASE ${ldap_base_dn}
    BINDDN uid=service_nextcloud,ou=people,${ldap_base_dn}
  '';
}
