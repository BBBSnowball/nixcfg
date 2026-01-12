# This software really isn't so nice:
# - Unfree license is annoying.
# - Version in nixpkgs is quite old.
# - We are supposed to use elasticsearch-setup-passwords
#   to change all the default passwords (ouch!).
#   - It doesn't seem to have any batch mode in the version that is in
#     the version that is in nixpkgs.
#   - We have to set $ES_HOME and create some symlinks in $ES_HOME/bin
#     to make it work, at all.
# - The NixOS module adds a script that waits for the daemon to respond
#   to HTTP requests and that script doesn't work with authorization.
#
# Well, here are the manual steps:
# - ES_HOME=/var/lib/elasticsearch ES_JAVA_HOME=/nix/store/fpfsb0fip56sdiphcfjdym87izgyf82d-openjdk-headless-11.0.29+7 elasticsearch-setup-passwords auto
# - Write down the passwords.
# - Create the role and user, see https://docs.joinmastodon.org/admin/elasticsearch/#security
# - Write password into secret file elasticsearch-pw-for-mastodon.
# - Restart container.
# - Fill Elasticsearch: `mastodon-tootctl search deploy`
{ lib, ports, ... }:
{
  services.elasticsearch = {
    enable = true;
    port = ports.elasticsearch.port;
    tcp_port = ports.elasticsearch-internal.port;
    single_node = true;
    extraConf = ''
      xpack.security.enabled: true
      #discovery.type: single-node  # already set by NixOS module
    '';
  };

  nixpkgs.allowUnfreeByName = [
    "elasticsearch"
  ];

  # The post-startup script just waits for the instance to respond to
  # HTTP requests but that won't work without authentication.
  systemd.services.elasticsearch.postStart = lib.mkForce "";
}
