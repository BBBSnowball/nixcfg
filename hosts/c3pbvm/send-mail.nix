{ mainFlake, domain, privateForHost, secretForHost, ... }:
{
  imports = [ mainFlake.nixosModules.sendmail ];

  programs.sendmail-to-smarthost = {
    enable = true;
    enableNotifyService = true;
    inherit (privateForHost.mailConfig) smtpHost sender adminEmail;
    passwordFile = "${secretForHost}/smtp-password.txt";
  };
}
