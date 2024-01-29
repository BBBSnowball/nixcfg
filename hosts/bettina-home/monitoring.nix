{ pkgs, config, privateForHost, ... }:
let
  muninSshConfig = pkgs.writeText "munin-ssh-config" ''
    # Default values of `ssh_options` in Munin
    # (This disables host key checking which isn't great but should be ok in our case.)
    ChallengeResponseAuthentication no
    #StrictHostKeyChecking no
    StrictHostKeyChecking accept-new

    Host ha
      User root
      HostName ${privateForHost.homeassistantIP}
      # The real system, not the SSH addon.
      #NOTE This has to be repeated in the Munin config because Munin will pass `-o Port=...` to SSH,
      #     which superseedes our setting here.
      Port 22222
      #IdentityFile $CREDENTIALS_DIRECTORY/munin-ssh-key
      IdentityFile /run/credentials/munin-cron.service/munin-ssh-key
  '';

  # error output of SSH seems to go nowhere so we redirect it to a log file
  sshWithLog = pkgs.writeShellScript "munin-ssh" ''
    exec 2>>/var/log/munin/ssh.txt
    set -x
    date >&2
    #echo CREDENTIALS_DIRECTORY=$CREDENTIALS_DIRECTORY
    #ls -l $CREDENTIALS_DIRECTORY >&2
    exec ${pkgs.openssh}/bin/ssh "$@"
  '';

  sendMailAlert = pkgs.writeShellScript "munin-send-mail" ''
    ( echo "Subject: $1"; echo ""; cat ) | \
    ${pkgs.msmtp}/bin/sendmail "${privateForHost.adminEmail}"
  '';
in
{
  services.munin-cron = {
    enable = true;

    extraGlobalConfig = ''
      #ssh_command "${pkgs.openssh}/bin/ssh"
      ssh_command "${sshWithLog}"
      ssh_options -F ${muninSshConfig}

      contact.syslog.command logger -p user.crit -t "Munin-Alert"
      contact.email.command ${sendMailAlert} "Munin ${var:worst}: ${var:group}::${var:host}::${var:plugin}"
      #contact.email.always_send warning critical
    '';

    hosts = ''
      [${config.networking.hostName}]
      address localhost

      #df._dev_dm_0.critical = 80
      #df._dev_dm_0.warning = 70

      [homeassistant]
      # see notes.txt w.r.t. configuration in the VM
      address ssh://ha:22222/mnt/overlay/muninlite
    '';
  };
  services.munin-node.enable = true;

  systemd.services.munin-cron = {
    serviceConfig.SetCredential = [ "munin-ssh-key:" ];  # fallback value
    serviceConfig.LoadCredential = [
      "munin-ssh-key:/etc/nixos/secret/by-host/bettina-home/munin-ssh-key"
    ];

    path = [ pkgs.openssh pkgs.util-linux ];
  };

  services.logrotate = {
    enable = true;
    settings.munin = {
      files = [
        "/var/log/munin/ssh.txt"
        "/var/log/munin/.munin-*.log"
      ];
      frequency = "daily";
      minsize = "1M";
      rotate = 10;
      delaycompress = true;
    };
  };
}
