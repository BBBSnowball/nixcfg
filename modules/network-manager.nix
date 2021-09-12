{
  networking.networkmanager.enable = true;

  systemd.services.NetworkManager.preStart = ''
    mkdir -p /etc/NetworkManager/system-connections/
    install -m 700 -t /etc/NetworkManager/system-connections/ /etc/nixos/secret/nm-system-connections/*
  '';
}
