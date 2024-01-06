{ pkgs, ... }:
let
  port = 51820;
in
{
  networking.firewall = {
    allowedUDPPorts = [ port ];
  };

  networking.wireguard.interfaces = {
    wg0 = {
      ips = [ "10.100.0.1/24" ];
      listenPort = port;

      # ( name=wireguard-test-fw; umask 077 && cd /etc/nixos/secret_local && wg genkey >"$name.priv" && wg pubkey <"$name.priv" >"$name.pub" )
      # ( umask 077 && wg genpsk >/etc/nixos/secret_local/wireguard-test-pixel6a.psk )
      privateKeyFile = "/etc/nixos/secret_local/wireguard-test-fw.priv";

      peers = [
        {
          publicKey = "36R6e2trVU9RS8MXohGbvqxXmFMp5/f2Qd9aSs50ViM=";
          presharedKeyFile = "/etc/nixos/secret_local/wireguard-test-pixel6a.psk";
          allowedIPs = [ "10.100.0.2/32" ];
        }
      ];
    };
  };

  systemd.network.wait-online.ignoredInterfaces = [ "wg0" ];
  # https://github.com/NixOS/nixpkgs/issues/180175#issuecomment-1186152020
  networking.networkmanager.unmanaged = [ "wg0" ];
  # -> doesn't help, so...
  systemd.services.NetworkManager-wait-online.enable = false;
  #systemd.services.NetworkManager-wait-online.serviceConfig.ExecStart = "${pkgs.coreutils}/bin/true";
}
