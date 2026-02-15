{ domain, privateForHost, secretForHost, ... }:
let
  # use mail credentials of Mastodon container, for now
  # (This is mostly for munin to monitor disk space of Mastodon container.)
  name = "mastodon";
  inherit (privateForHost.${name}) domain;
  inherit (privateForHost.${name}) smtpHost;
in
{
  imports = [
    ../containers/parts/sendmail-to-smarthost.nix
  ];

  programs.sendmail-to-smarthost = {
    enable = true;
    inherit smtpHost;
    sender = "noreply@${domain}";
    passwordFile = "${secretForHost}/${name}/noreply-smtp-password";
  };
}
