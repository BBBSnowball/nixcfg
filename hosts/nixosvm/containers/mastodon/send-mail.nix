{ domain, smtpHost, ... }:
{
  imports = [
    ../parts/sendmail-to-smarthost.nix
  ];

  programs.sendmail-to-smarthost = {
    enable = true;
    inherit smtpHost;
    sender = "noreply@${domain}";
    #passwordFile = "/run/credstore/secret_noreply-smtp-password";
    passwordFile = "secret_noreply-smtp-password";  # used with LoadCredential so credential name is fine
  };
}
