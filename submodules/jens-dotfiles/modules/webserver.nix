{ config, lib, pkgs, ... }:

# unused module, contains bad/invalid configuration
# kept as reference

with lib;

let
  cfg = config.services.webserver;
  ssoPort = 8001;
  ssoService = "http://127.0.0.1:${toString ssoPort}";
in
{
  options.services.webserver = {
    enable = mkEnableOption "Enable webserver with ACME SSL and SSO";
    host = mkOption {
      type = types.str;
      description = "The main dns hostname of the server";
    };
    loginHost = mkOption {
      type = types.str;
      default = "login.${cfg.host}";
      description = "The login hostname of the server";
    };
  };
  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    services.nginx = {
      enable = true;

      appendHttpConfig = ''
        sendfile on;
        #tcp_nopush on;
        #tcp_nodelay on;
        keepalive_timeout 65;
        types_hash_max_size 4096;
        server_names_hash_bucket_size 128;
      '';

      virtualHosts = {
        "${cfg.host}" = {
          #default = true;
          useACMEHost = "${cfg.host}";
          forceSSL = true;
          extraConfig = ''
            error_page 401 = @error401;
          '';
          locations = {
            "=/" = {
              return  = ''200 "Hello World!"'';
            };
            "/auth" = {
              proxyPass = "${ssoService}/auth";
              extraConfig = ''
                internal;
                proxy_pass_request_body off;
                proxy_set_header Content-Length "";
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Origin-URI $request_uri;
                proxy_set_header X-Host $http_host;
              '';
            };
            "/login" = {
              proxyPass = "${ssoService}";
              extraConfig = ''
                proxy_set_header X-Original-URI $request_uri;
                proxy_set_header X-Real-IP $remote_addr;
              '';
            };
            "/logout" = {
              proxyPass = "${ssoService}/logout?go=https://${cfg.host}/login";
              extraConfig = ''
                proxy_set_header X-Original-URI $request_uri;
                proxy_set_header X-Real-IP $remote_addr;
              '';
            };

            "@error401" = {
              # "303 See Other" instructs the client to do a temporary redirect but change
              # the request method to GET
              return = "303 https://${cfg.host}/login?go=$scheme://$http_host$request_uri";
            };

            "/ip" = {
              extraConfig = "default_type text/plain;";
              return = ''200 $remote_addr'';
            };
            "/ip.json" = {
              extraConfig = "default_type application/json;";
              return = ''200 "{\"ip\":\"$remote_addr\"}"'';
            };
            "=/secret" = {
              alias = "/srv/http/index.html";
              extraConfig = ''
                default_type text/html;

                auth_request /auth;

                # Automatically renew SSO cookie on request
                auth_request_set $cookie $upstream_http_set_cookie;
                add_header Set-Cookie $cookie;
              '';
            };
          };
        };
        "${cfg.loginHost}" = {
          useACMEHost = "${cfg.host}";
          forceSSL = true;
          locations = {
            "/" = {
              proxyPass = "${ssoService}";
              extraConfig = ''
                proxy_set_header X-Original-URI $request_uri;
                proxy_set_header X-Real-IP $remote_addr;
              '';
            };
          };
        };
      };
    };

    systemd.services.nginx.wants = [
      "acme-selfsigned-${cfg.host}.service"
      "acme-${cfg.host}.service"
    ];
    systemd.services.nginx.after = [ "acme-selfsigned-${cfg.host}.service" ];
    systemd.services.nginx.before = [ "acme-${cfg.host}.service" ];

    security.acme = {
      certs = {
        "${cfg.host}" = {
          server = "https://acme-staging-v02.api.letsencrypt.org/directory";
          webroot = "/var/lib/acme/acme-challenge";
          extraDomains = {
            "${cfg.loginHost}" = null;
          };
          postRun = ''
            systemctl start --failed nginx.service
            systemctl reload nginx.service
          '';
          group = "nginx";
          allowKeysForGroup = true;
        };
      };
    };

    # acme-${host}.service needs to be started at least once
    # after that nginx.service needs to be restarted

    services.nginx.sso = {
      enable = true;
      configuration = {
        cookie = {
          domain = ".queezle.net";
          authentication_key = "D5b3KocU3SXUCjwYku8B5NiUTbmtGr9hEEpsZWlC0xykyP6YaDkMc1Pn06BwXfJis8dGyJlbieWHpmmO6XWARt7FE6ZvKm66fzEZ";
        };

        listen = {
          addr = "127.0.0.1";
          port = 8001;
        };

        login = {
          title = "queezle.net - Login";
          default_method = "simple";
          default_redirect = "https://${cfg.host}/";
          hide_mfa_field = true;
          names = {
            simple = "Username / Password";
          };
        };

        providers = {
          simple = {
            enable_basic_auth = false;

            users = {
              jens = "$2y$12$zC3JojFQ1Ss.ZW9RX6Y.i.t43FnsHifuUfwy5hrvwmWfse7HYphvS";
              # foobar
              beini = "$2y$12$73/wfnJo9ChXkTSOGNUZneXhgo74lkoX37jeq9CMRopHNeraoQ.rS";
            };
            groups = {
              wheel = [ "jens" ];
            };
          };
        };

        audit_log = {
          targets = ["fd://stdout"];
          events = ["access_denied" "login_success" "login_failure" "logout" "validate"];
          headers = ["X-Origin-URI"];
          trusted_ip_headers = ["X-Forwarded-For" "RemoteAddr" "X-Real-IP"];
        };

        acl = {
          rule_sets = [
            {
              #rules = [ { field = "x-application"; equals = "MyApp"; } ];
              allow = [ "jens" ];
            }
          ];
        };
      };
    };
  };
}
