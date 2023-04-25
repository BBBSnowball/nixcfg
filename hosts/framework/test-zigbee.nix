{
  imports = [
    ../../homeautomation
  ];

  services.mosquitto = {
    enable = true;
    listeners = [ {
      address = "localhost";
      #omitPasswordAuth = true;
      users.guest.password = "guest";
    } ];
  };
}
