{ pkgs, ... }:
{
  virtualisation.libvirtd.enable = true;
  users.users.user.extraGroups = [ "libvirtd" ];

  services.virtlyst.enable = true;
  services.virtlyst.adminPassword = "password";  # Well....
  # SSH doesn't seem to be tested - at least for the Nix package.
  # In addition, I had to create ~virtlyst/.ssh/{id_rsa,config,known_hosts}
  # with appropriate contents. I have set the user in the SSH config because
  # the user field on the web interface seems to be ignored (but I probably
  # could have added it to the hostname).
  systemd.services.virtlyst.path = [ pkgs.openssh ];
}

