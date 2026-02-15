{ privateForHost, secretForHost, ... }:
let
  p = privateForHost.mail;
in
{
  programs.sendmail-to-smarthost = {
    enable = true;
    inherit (p) smtpHost username adminEmail;
    sender = p.from;
    passwordFile = "${secretForHost}/msmtp-password";
  };
}
