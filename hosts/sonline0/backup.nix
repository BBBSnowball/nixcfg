{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    duplicity lftp
    (pkgs.runCommand "backup" {} ''
      mkdir -p $out/bin
      ln -s ${./backup.sh} $out/bin/backup
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
    restartIfChanged = false;
  };
}
