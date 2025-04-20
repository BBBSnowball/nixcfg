{ lib, pkgs, config, domain, ... }:
let
  inherit (import ./nginx-ldap-auth-service.nix { inherit lib pkgs; }) env;
  basedn = config.services.lldap.settings.ldap_base_dn;

  serviceSettings = {
    # https://nginx-ldap-auth-service.readthedocs.io/en/latest/configuration.html
    environment = {
      LDAP_URI = "ldap://localhost:${toString config.services.lldap.settings.ldap_port}";
      LDAP_BINDDN = "uid=service_nginx,ou=people,${basedn}";
      #LDAP_BASEDN = basedn;
      LDAP_BASEDN = "ou=people,${basedn}";
      LDAP_STARTTLS = "0";
      #LDAP_USER_BASEDN = ",ou=people,${basedn}";  # no good: it will omit "uid=" because it assumes that we use AD
      #LDAP_GET_USER_FILTER = "{username_attribute}={username}";  # already the default and not used in authenticate()
      #LDAP_AUTHORIZATION_FILTER = "(&(objectclass=person)(memberOf=cn=Omas_intern,ou=groups,${basedn})(uid={username},ou=people,${basedn}))";
      # -> uid without basedn because search uses base=LDAP_BASEDN
      LDAP_AUTHORIZATION_FILTER = "(&(objectclass=person)(memberOf=cn=Omas_intern,ou=groups,${basedn})(uid={username}))";
      AUTH_REALM = "Omas intern";
      SESSION_MAX_AGE = toString (2*24*3600);
      COOKIE_DOMAIN = domain;
      # Workaround: Entries without `display_name` don't have any `cn` but we don't need that anyway, so let's use the uid.
      LDAP_FULL_NAME_ATTRIBUTE = "uid";

      #DEBUG = "1";
    };
    # contains SECRET_KEY, CSRF_SECRET_KEY and LDAP_PASSWORD
    # openssl rand -hex 64, pwgen 20 1
    serviceConfig.EnvironmentFile = "/run/credstore/secret_nginx-ldap-env";
  };
in
{
  systemd.services.nginx-ldap-auth = lib.mkMerge [ serviceSettings {
    serviceConfig.ExecStart = "${env}/bin/nginx-ldap-auth start -k %d/secret_nginx-ldap-key.pem -c %d/secret_nginx-ldap-cert.pem";

    serviceConfig.DynamicUser = true;

    serviceConfig.LoadCredential = [
      # openssl req -x509 -newkey rsa:4096 -keyout nginx-ldap-key.pem -out nginx-ldap-cert.pem -sha256 -days 36500 -nodes -subj "/CN=localhost"
      "secret_nginx-ldap-key.pem"
      "secret_nginx-ldap-cert.pem"
    ];

    wantedBy = [ "multi-user.target" ];
  } ];

  systemd.services.nginx-ldap-auth-print-settings = lib.mkMerge [ serviceSettings {
    serviceConfig.ExecStart = "${env}/bin/nginx-ldap-auth settings";

    serviceConfig.DynamicUser = true;
  } ];

  systemd.services.nginx.serviceConfig.LoadCredential = [ "secret_nginx-ldap-cert.pem" ];
  systemd.services.nginx.serviceConfig.RuntimeDirectory = "nginx";

  services.nginx.commonHttpConfig = ''
    proxy_cache_path /run/nginx/auth_cache keys_zone=auth_cache:10m use_temp_path=off;

    # https://stackoverflow.com/questions/67548886/remove-specific-cookie-in-nginx-reverse-proxy
    map $http_cookie $altered_cookie1 {
      "~(.*)(^|;\s)nginxauth=(\"[^\"]*\"|[^\s]*[^;]?)(\2|$|;$)(.*)" $1$4$5;
      #default $http_cookie;
      default "";
    }
    map $altered_cookie1 $altered_cookie {
      "~(.*)(^|;\s)nginxauth_csrf=(\"[^\"]*\"|[^\s]*[^;]?)(\2|$|;$)(.*)" $1$4$5;
      default $altered_cookie1;
    }
  '';
  services.nginx.virtualHosts."intern.${domain}" = {
    # see https://nginx-ldap-auth-service.readthedocs.io/en/latest/nginx.html
    locations."/".extraConfig = ''
      auth_request /check-auth;

      # If the auth service returns a 401, redirect to the login page.
      error_page 401 =200 /auth/login?service=$request_uri;

      # There is no reason to send the auth cookie to any proxied applications.
      proxy_hide_header Cookie;
      proxy_set_header  Cookie $altered_cookie;
    '';
    locations."/auth".extraConfig = ''
      proxy_pass https://127.0.0.1:8888/auth;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      # We need to pass in the CSRF cookie we set in the login code so
      # that we can validate it
      proxy_set_header Cookie nginxauth_csrf=$cookie_nginxauth_csrf;
      proxy_ssl_trusted_certificate /run/credentials/nginx.service/secret_nginx-ldap-cert.pem;
      proxy_hide_header X-Cookie-Name;
      proxy_hide_header X-Cookie-Domain;
      proxy_hide_header X-Auth-Realm;
    '';
    locations."/check-auth".extraConfig = ''
      internal;
      proxy_pass https://127.0.0.1:8888/check;
  
      # Ensure that we don't pass the user's headers or request body to
      # the auth service.
      proxy_pass_request_headers off;
      proxy_pass_request_body off;
      proxy_set_header Content-Length "";
  
      # We use the same auth service for managing the login and logout and
      # checking auth.  The SessionMiddleware, which is used for all requests,
      # will always be trying to set cookies even on our /check path.  Thus we
      # need to ignore the Set-Cookie header so that nginx will cache the
      # response.  Otherwise, it will think this is a dynamic page that
      # shouldn't be cached.
      proxy_ignore_headers "Set-Cookie";
      proxy_hide_header "Set-Cookie";
  
      # Cache our auth responses for 10 minutes so that we're not
      # hitting the auth service on every request.
      proxy_cache auth_cache;
      proxy_cache_valid 200 10m;
  
      proxy_set_header Cookie nginxauth=$cookie_nginxauth;
      proxy_cache_key "$http_authorization$cookie_nginxauth";
      proxy_ssl_trusted_certificate /run/credentials/nginx.service/secret_nginx-ldap-cert.pem;
    '';
  };
}
