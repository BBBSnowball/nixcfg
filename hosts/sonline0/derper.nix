{ lib, pkgs, config, privateForHost, secretForHost, ... }:
let
  # 3478 is already used by coturn.
  stunport = 3480;
  derpport = 1443;

  domain = "derp2.${privateForHost.infoDomain}";

  # Test with:
  # - tailscale debug derp sonline0
  # - tailscale status
  # - tailscale netcheck
  # see https://headscale.net/stable/ref/debug/
  # (Some errors are not detected by `debug derp`, e.g. if derp refuses the
  #  client key, only `tailscale status` will complain, albeit without any
  #  helpful info.)

  cfg = config.services.tailscale.derper;
in
{
  services.tailscale.derper = {
    enable = true;
    domain = domain;
    configureNginx = false;
    openFirewall = false;

    port = derpport;
    stunPort = stunport;

    verifyClients = false;  # We will change that in the service, see below.
  };

  # set to false so we will notice if derper module enables tailscale daemon
  services.tailscale.enable = false;

  # We replace the start command because we need some options that are not
  # supported by the NixOS module, e.g. TLS and verify clients by URL.
  # see https://headscale.net/stable/ref/derp/
  # and https://github.com/tailscale/tailscale/blob/main/cmd/derper/README.md
  # and https://tailscale.com/docs/reference/derp-servers/custom-derp-servers
  systemd.services.tailscale-derper.serviceConfig.ExecStart = lib.mkForce (
    ''${lib.getExe' cfg.package "derper"}''
    + " -hostname=${cfg.domain}"
    + " -home blank"
    # main port will use TLS when we set certmode
    + " -a :${toString cfg.port}"
    + " -stun-port ${toString cfg.stunPort}"
    + " -http-port -1"
    # derper will store its key here
    + " -c /var/lib/derper/derper.key"
    # builtin acme support doesn't support DNS verification with custom script
    # so we use manual mode
    + " -certdir /run/credentials/tailscale-derper.service"
    + " -certmode manual"
    # ask headscale whether clients are allowed to connect
    + " -verify-client-url https://headscale.${privateForHost.infoDomain}/verify"
    + " -verify-client-url-fail-open false"
  );

  systemd.services.tailscale-derper.after = [
    # Wait for file to exist (selfsigned) or acme to be done?
    # -> No reason to start before acme is done, I think.
    "acme-${domain}.service"
    "acme-order-renew-${domain}.service"
  ];

  systemd.services.tailscale-derper.serviceConfig.LoadCredential = [
    ''${domain}.crt:/var/lib/acme/${domain}/fullchain.pem''
    ''${domain}.key:/var/lib/acme/${domain}/key.pem''
  ];


  #NOTE This needs additional config on mailinabox.
  #  see ../bettina-home/web-acme/README.md
  #  - `_acme-challenge.${domain}`: `CNAME something.domain-without-dnssec.`
  #  - add something.domain-without-dnssec to /etc/nsd/nsd.conf.d/zones2.conf
  #  - SSH forced-command for our SSH key

  security.acme.acceptTerms = true;
  security.acme.certs."${domain}" =
  let
    dnsScript = pkgs.writeShellScript "acme-dns-mailinabox" ''
      # default shell is nologin, which will break ssh
      export SHELL=${pkgs.bash}/bin/bash
      if [ -z "$CREDENTIALS_DIRECTORY" -o ! -e "$CREDENTIALS_DIRECTORY/ssh_config" ] ; then
        echo "acme dns script: credentials are missing"
        exit 1
      fi
      cd "$CREDENTIALS_DIRECTORY"
      exec ${pkgs.openssh}/bin/ssh -F $PWD/ssh_config -o BatchMode=yes target -- "$@"
      # &>/var/lib/acme/${domain}/debug.log
    '';
    environmentFile = pkgs.writeText "acme.env" ''
      EXEC_MODE=
      EXEC_PATH=${dnsScript}
      # default values
      #EXEC_POLLING_INTERVAL=2
      #EXEC_PROPAGATION_TIMEOUT=60
      #EXEC_SEQUENCE_INTERVAL=60
    '';
  in {
    email = privateForHost.acmeEmail;
    dnsProvider = "exec";
    extraDomainNames = [
    ];
    inherit environmentFile;
    dnsResolver = "1.1.1.1:53";
    dnsPropagationCheck = false;  # disable check of all primary servers
    group = "headscale";
    # README says that a restart is required and I don't see any code for reloading files on a signal.
    # It will use `try-reload-or-restart`, so that should be fine.
    reloadServices = [ "derper.service" ];

    # create symlinks with names that derper will use
    #postRun = ''
    #  ln -sfT fullchain.pem ${domain}.crt
    #  ln -sfT key.pem ${domain}.key
    #'';
  };

  systemd.services."acme-${domain}".serviceConfig.LoadCredential = [
    "ssh:${secretForHost}/acme-dns-update-ssh"
  ];
  systemd.services."acme-order-renew-${domain}".serviceConfig.LoadCredential = [
    "ssh:${secretForHost}/acme-dns-update-ssh"
  ];
}
