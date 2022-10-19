{
  networking.hostName = "hedgedoc";
  services.hedgedoc = {
    enable = true;
    configuration = {
      db.dialect = "sqlite";
      db.storage = "/var/lib/hedgedoc/db.hedgedoc.sqlite";
      email = false;
      host = "::";
      port = 3000;
      useCDN = false;
      # disable strict security because we don't have SSL here
      hsts.enable = false;
      #allowOrigin = [ "*" ];
      # blocks our own resources, probably because we don't have a domain name
      # and we don't know the dynamic IP of our host
      csp.enable = false;
    };
  };

  # We cannot create users on the host (or rather we don't want to)
  # so let's enable DynamicUser and mount in the relevant paths.
  systemd.services.hedgedoc = {
    serviceConfig.DynamicUser = true;
    serviceConfig.BindPaths = "/srv/hedgedoc:/var/lib/hedgedoc";
  };
}
