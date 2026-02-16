{ privateForHost, secretForHost, ... }:
{
  #imports = [ mainFlake.nixosModules.sendmail ];

  programs.sendmail-to-smarthost = {
    enable = true;
    enableNotifyService = true;
    inherit (privateForHost.mail) smtpHost smtpHostReal username adminEmail;
    #inherit (privateForHost.mail) smtpPort;
    sender = privateForHost.mail.from;
    passwordFile = "${secretForHost}/msmtp-password";
  };
}
