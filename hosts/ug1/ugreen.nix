{ ... }:
{
  #systemd.watchdog.runtimeTime = "1min";
  #systemd.watchdog.kexecTime = "10min";
  #systemd.watchdog.rebootTime = "10min";

  systemd.settings.Manager = {
    RuntimeWatchdogSec = "1min";
    KExecWatchdogSec = "10min";
    RebootWatchdogSec = "10min";
  };
}
