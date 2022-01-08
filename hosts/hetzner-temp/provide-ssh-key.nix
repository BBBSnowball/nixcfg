{ pkgs, ... }:
{
  systemd.services."provide-ssh-key" = {
    unitConfig.ConditionPathExists = "/etc/ssh-shared-secret";
    serviceConfig.DynamicUser = true;
    serviceConfig.RuntimeDirectory = "provide-ssh-key";
    serviceConfig.PermissionsStartOnly = true;
    serviceConfig.ProtectSystem = "full";

    path = with pkgs; [ openssl socat gnutar ];

    preStart = ''
      umask 077
      cd $RUNTIME_DIRECTORY
      cat /etc/ssh/ssh_host_*_key.pub >host-keys
      openssl dgst -sha256 -hmac <(cat /etc/ssh-shared-secret) -binary <host-keys | openssl enc -base64 -A >host-keys.sig
      tar -cf keys.tar host-keys host-keys.sig
      rm host-keys{,.sig}
    '';
    script = ''
      cd $RUNTIME_DIRECTORY
      ${pkgs.socat}/bin/socat -U tcp-listen:36431,fork exec:"cat keys.tar"
    '';
  };

  networking.firewall.allowedTCPPorts = [ 36431 ];
}
