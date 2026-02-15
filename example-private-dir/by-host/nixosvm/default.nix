{
  vmNumber = 42;
  adminEmail = "admin@example.com";

  sonline0 = import ../sonline0-shared/sonline0-common.nix;

  janina = {
    url1 = "1.example.com";
    url2 = "2.example.com";
    url3 = "3.example.com";
    url4 = "4.example.com";
    smtpHost = "mail.example.com";
  };

  mastodon = {
    domain = "m.example";
    smtpHost = "mail.example.com";
    smtpHostReal = "mail.example.com";
  };

  omas = {
    domain = "o.example";
    smtpHost = "mail.example.com";
    smtpHostReal = "mail.example.com";
    reverse_proxy_ip = "1.2.3.4";
  };
}