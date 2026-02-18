{ pkgs, mainFlake, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  noipv6 = mainFlake.packages.${system}.noipv6;
in
{
  environment.systemPackages = with pkgs; [
    duplicity lftp
    (pkgs.runCommand "backup" {} ''
      mkdir -p $out/bin
      #ln -s ${./backup.sh} $out/bin/backup
      for target in dedibackup hetzner ; do
        echo -e "#!/bin/sh\ntarget=$target exec ${./backup.sh} \"\$@\"" >$out/bin/backup-$target
        chmod +x $out/bin/backup-$target
      done
    '')
  ];

  systemd.timers.backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      #OnCalendar = "daily";  # This would be at midnight, when the system might still be in use.
      OnCalendar = "*-*-* 06:00:00";
      #Persistent = "yes";
      FixedRandomDelay = true;
      RandomizedDelaySec = 3600;
    };
  };

  #NOTE Log goes to /var/log/duplicity-backup-to-ftp.log
  systemd.services.backup = {
    description = "Backup whole system with duplicity";

    path = with pkgs; [ bash duplicity procps lftp ];
    serviceConfig.Type = "oneshot";
    serviceConfig.ExecStart = "${./backup.sh} cron";
    environment.LD_PRELOAD = noipv6;  # only IPv4, more reliable
    environment.target = "hetzner";
    restartIfChanged = false;

    # send mail on failure
    unitConfig.OnFailure = "notify-by-mail@%n";

    # don't wait a whole day before we try again
    serviceConfig.Restart = "on-failure";
    serviceConfig.RestartSec = "2h";
  };
  programs.sendmail-to-smarthost.enableNotifyService = true;
}
