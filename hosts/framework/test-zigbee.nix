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
      users.guest.acl = [ "readwrite #" ];
    } {
      address = "192.168.122.1";
      #omitPasswordAuth = true;
      users.guest.password = "guest";
      users.guest.acl = [ "readwrite #" ];
    } ];
  };
}
