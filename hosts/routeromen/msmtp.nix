{ lib, pkgs, privateForHost, secretForHost, ... }:
{
  programs.msmtp = {
    enable = true;
    setSendmail = true;
    accounts.default = {
      auth = true;
      inherit (privateForHost.smtp) user host;
      passwordeval = "cat ${secretForHost}/smtp_password";
      from = builtins.replaceStrings ["@"] ["+%U-%H@"] privateForHost.smtp.user;
      allow_from_override = false;
    };
    defaults = {
      aliases = pkgs.writeText "aliases" ''
        root: ${privateForHost.smtp.recipient}
      '';
      port = 587;
      tls = true;
    };
  };
}
