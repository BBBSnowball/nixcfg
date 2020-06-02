{ pkgs, config, lib, ... }:
let
  domain = lib.fileContents ../private/trueDomain.txt;
in {
  nixpkgs.overlays = [
    (import ./matrix-synapse-update.nix)
  ];

  networking.firewall.allowedTCPPorts = [8448];

  services.matrix-synapse = {
    enable = true;

    allow_guest_access  = false;
    enable_registration = false;
    url_preview_enabled = true;

    dataDir = "/var/data/matrix-synapse";
    database_type = "sqlite3";

    server_name = "test.${domain}";
    public_baseurl = "https://test.${domain}/";
    listeners = let
      default = addr: port: {
        bind_address = addr;
        port = port;
        tls = true;
        type = "http";
        x_forwarded = false;
        resources = [
          {
            compress = true;
            #names = [ "client" "webclient" ];
            names = [ "client" ];
          }
          {
            compress = false;
            names = [ "federation" ];
          }
        ];
      };
      #local = ["::1" "127.0.0.1"];  # not supported by NixOS module
      local = "127.0.0.1";
    in [
      ((default ""    8448) // { tls = true;  x_forwarded = true;  })
      ((default local 8008) // { tls = false; x_forwarded = true;  })
      { bind_address = local; port = 9000; type = "manhole"; resources = []; }
    ];
    no_tls = false;
    tls_certificate_path = "/etc/nixos/secret/matrix-synapse/homeserver.tls.crt";
    tls_dh_params_path   = "/etc/nixos/secret/matrix-synapse/homeserver.tls.dh";
    tls_private_key_path = "/etc/nixos/secret/matrix-synapse/homeserver.tls.key";


    extraConfig = ''
      use_presence: true
      enable_group_creation: true
      group_creation_prefix: "unofficial/"
      acme:
        enabled: false
      signing_key_path: "/etc/nixos/secret/matrix-synapse/homeserver.signing.key"
    '';
    extraConfigFiles = [
      "/etc/nixos/secret/matrix-synapse/homeserver-secret.yaml"
      "/etc/nixos/secret/matrix-synapse/oidc-config.yaml"
    ];
    app_service_config_files = [
      #"/etc/matrix-synapse/matrix_irc_hackint.yaml"
      "/etc/nixos/secret/matrix-synapse/mautrix-telegram.yaml"
    ];
  };
}
