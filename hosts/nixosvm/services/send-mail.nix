{ mainFlake, domain, privateForHost, secretForHost, ... }:
let
  # use mail credentials of Mastodon container, for now
  # (This is mostly for munin to monitor disk space of Mastodon container.)
  name = "mastodon";
  inherit (privateForHost.${name}) domain;
  inherit (privateForHost.${name}) smtpHost;

  modules = mainFlake.nixosModules;
in
{
  imports = [
    modules.sendmail
  ];

  programs.sendmail-to-smarthost = {
    enable = true;
    inherit smtpHost;
    sender = "noreply@${domain}";
    passwordFile = "${secretForHost}/${name}/noreply-smtp-password";
  };
}
