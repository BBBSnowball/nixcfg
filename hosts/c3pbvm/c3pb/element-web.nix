{ pkgs, config, lib, privateForHost, secretForHost, ... }:
let
  domain = privateForHost.trueDomain;

  ourConfig = {
    "default_server_config" = {
        "m.homeserver" = {
            "base_url" = "https://${domain}";
            "server_name" = domain;
        };
        #"m.identity_server" = {
        #    "base_url" = "https://vector.im"
        #};
    };
    "disable_custom_urls" = true;
    "disable_guests" = true;
    "disable_login_language_selector" = false;
    "disable_3pid_login" = true;
    "brand" = "Element";
    "integrations_ui_url" = "/intentionally-not-present";
    "integrations_rest_url" = "/intentionally-not-present";
    "integrations_widgets_urls" = [];
    "bug_report_endpoint_url" = "";
    "defaultCountryCode" = "DE";
    default_country_code = "DE";
    "showLabsSettings" = true;
    show_labs_settings = true;
    "features" = {
        "feature_new_spinner" = false;
    };
    #"default_federate" = true;
    #"default_theme" = "light";
    room_directory.servers = [
      "matrix.org"
      domain
    ];
    #"piwik" = false;
    #"enable_presence_by_hs_url" = {
    #    "https://matrix.org" = false;
    #    "https://matrix-client.matrix.org" = false
    #};
    #"setting_defaults" = {
    #    "breadcrumbs" = true
    #};
    #"jitsi" = {
    #    "preferredDomain" = "jitsi.riot.im"
    #};
  };

  upstreamPkg = pkgs.element-web;
  upstreamConfig = builtins.fromJSON (builtins.readFile "${upstreamPkg}/config.json");
  finalConfig = lib.recursiveUpdate upstreamConfig ourConfig;
  #finalConfigJson = lib.generators.toJSON { } finalConfig;
  finalConfigJson = builtins.toJSON { } finalConfig;
  element-web-with-config = pkgs.runCommand upstreamPkg.name {
    inputPkg = upstreamPkg;
    #configJson = finalConfigJson;
    #passAsFile = [ "configJson" ];
    inherit (pkgs) jq;
  } ''
    PATH="$PATH":$jq/bin
    mkdir $out
    for x in $inputPkg/* ; do
      ln -s "$x" $out
    done
    mv $out/{config.json,config.nixpkgs.json}
    #jq <$out/config.json >$out/config.nixpkgs.json
    #rm $out/config.json
    #jq < $configJsonPath > $out/config.json
    jq -s '.[0] * $conf' $out/config.nixpkgs.json --argjson "conf" '${builtins.toJSON ourConfig}' > "$out/config.json"
  '';

  element-web-old = pkgs.callPackage ./element-web-old.nix {};
in {
  environment.etc."current-element-web".source = element-web-with-config;

  services.nginx = {
    enable = true;

    virtualHosts.default.root = "/dev/null";
    virtualHosts."matrix-client.${domain}" = {
      root = pkgs.runCommand "matrix-client-root" {} ''
        mkdir $out
        ln -s ${element-web-with-config} $out/matrix_client
        ln -s matrix_client/fonts $out/fonts
        ln -s ${element-web-old} $out/matrix_client-${element-web-old.version}
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}

