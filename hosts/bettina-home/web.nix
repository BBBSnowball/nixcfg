{ lib, pkgs, privateForHost, secretForHost, ... }:
let
  inherit (privateForHost) domain;
  domain1 = "bettina-home.${domain}";

  baseDomains = [
    domain1
    "vpn.${domain1}"
    "lokal.${domain1}"
  ];

  webServices = {
    wlan = {
      target = "http://localhost:8088/";
      icon = "favicon.ico";
      title = "Omada Controller (WLAN)";
    };
    zigbee = {
      target = "http://localhost:8086/";
      icon = "assets/favicon.a8299d0b.ico";
      title = "Zigbee2MQTT (Zigbee Geräte)";
    };
    ha = {
      target = "http://localhost:8123/";
      icon = "static/icons/favicon.ico";
      title = "Home Assistant";
    };
    munin = {
      target = "http://localhost:4949/";
      icon = "/static/favicon.ico";
      title = "Mumin (System Monitor)";
      nginxConfig = {
        locations."/".extraConfig = ''
          rewrite ^/$ munin/ redirect; break;
        '';
        locations."/munin/".extraConfig = ''
          alias /var/www/munin/;
          expires modified +310s;
        '';
      };
    };
    passwords = {
      target = "http://localhost:8000/";
      icon = "vw_static/vaultwarden-favicon.png";
      title = "Vaultwarden (Passwörter)";
    };
    speedport = {
      target = "http://192.168.2.1:80/";
      defaultUri = "6.0/gui/";
      icon = "6.0/gui/images/favicon.ico";
      title = "Router (Speedport)";
    };
    switch = {
      target = "http://172.18.18.4/";
      icon = "favicon.ico";
      #title = "Switch<br/><font size=1>(evtl muss man dem Laptop die 172.18.18.5/28 geben, damit das funktioniert)</font>";
      title = "Switch";
    };
  };

  webServicesAsLua = let
    x = lib.concatMapStringsSep "\n" ({ name, value}: ''
      webServicesInfo["${name}"] = {}
      webServicesInfo["${name}"].target = "${value.target}"
      webServicesInfo["${name}"].icon = "${value.icon or ""}"
      webServicesInfo["${name}"].title = "${value.title or name}"
      webServicesInfo["${name}"].defaultUri = "${value.defaultUri or ""}"
    '') (lib.attrsToList webServices);
  in pkgs.writeTextDir "webServicesInfo.lua" ''
    local webServicesInfo = {}
    ${x}
    return webServicesInfo
  '';

  sslSettings = {
    useACMEHost = domain1;
    #addSSL = true;   # provide HTTPS and let the user choose
    forceSSL = true;  # redirect to HTTPS if user tries to use HTTP
  };

  defaultVHost = {
    root = ./html;

    locations."/index.html".extraConfig = ''
      # only cache for a short time and only in memory
      # so we don't need manual updates and we notice
      # when network is down
      expires 60s;
      add_header Cache-Control "no-cache";

      # generate page with Lua because we want to adjust links
      # for the current origin
      default_type text/html;
      content_by_lua_file ${./html}/index.lua;
    '';
  };

  mapListToAttrs = f: xs: lib.listToAttrs (map f xs);
in
{
  services.nginx = {
    enable = true;

    additionalModules = [
      pkgs.nginxModules.lua
    ];
    # Lua module needs some additional libraries.
    # see https://github.com/NixOS/nixpkgs/issues/227759#issuecomment-1568677611
    # -> They are available in nixpkgs so no need to fetch them from Github.
    # -> Upstream fix: https://github.com/NixOS/nixpkgs/pull/269957
    commonHttpConfig = let
      # Version of Lua in nginx matches luajit instead of luajit_openresty
      # so that's what we use.
      inherit (pkgs.luajitPackages) lua lua-resty-core lua-resty-lrucache;
      inherit (lua) luaversion;

      luaPackagePath = [
        # seems to work in PR 269957 but not for us
        #"${lua-resty-core}/lib/?.lua"
        #"${lua-resty-lrucache}/lib/?.lua"

        "${lua-resty-core}/lib/lua/${luaversion}/?.lua"
        "${lua-resty-lrucache}/lib/lua/${luaversion}/?.lua"

        # add our own file
        "${webServicesAsLua}/?.lua"
      ];
    in
    # ";;" in lua_package_path adds the default path
    ''
      lua_package_path "${lib.concatStringsSep ";" luaPackagePath};;";
    '';

    virtualHosts = {
      # Client is using our IP address or some unknown host name.
      "default" = defaultVHost;
    }
    # add index page for each base domain
    // lib.flip mapListToAttrs baseDomains (name: {
      inherit name;
      value = defaultVHost // sslSettings;
    })
    # add proxy pass for each service on each base domain
    // lib.flip mapListToAttrs
    (lib.cartesianProductOfSets { baseDomain = baseDomains; service = lib.attrNames webServices; })
    ({ baseDomain, service }:
    let target = webServices.${service}.target; in
    {
      name = "${service}.${baseDomain}";
      value = sslSettings // (webServices.${service}.nginxConfig or {
        locations."/" = {
          proxyPass = target;
          proxyWebsockets = true;
        };
      });
    });
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  security.acme.acceptTerms = true;
  security.acme.certs."${domain1}" =
  let
    dnsScript = pkgs.writeShellScript "acme-dns-mailinabox" ''
      # default shell is nologin, which will break ssh
      export SHELL=${pkgs.bash}/bin/bash
      cd $CREDENTIALS_DIRECTORY
      exec ${pkgs.openssh}/bin/ssh -F $PWD/ssh_config -o BatchMode=yes target -- "$@"
      # &>/var/lib/acme/bettina-home.${domain}/debug.log
    '';
    environmentFile = pkgs.writeText "acme-bettina-home.env" ''
      EXEC_MODE=
      EXEC_PATH=${dnsScript}
      # default values
      #EXEC_POLLING_INTERVAL=2
      #EXEC_PROPAGATION_TIMEOUT=60
      #EXEC_SEQUENCE_INTERVAL=60
    '';
  in
  {
    email = privateForHost.acmeEmail;
    dnsProvider = "exec";
    extraDomainNames = [
      "*.${domain1}"
      "*.vpn.${domain1}"
      "*.lokal.${domain1}"
    ];
    inherit environmentFile;
    dnsResolver = "1.1.1.1:53";
    dnsPropagationCheck = false;  # disable check of all primary servers
    group = "nginx";
  };

  systemd.services."acme-${domain1}".serviceConfig.LoadCredential = [
    "ssh:${secretForHost}/acme-dns-update-ssh"
  ];
}
