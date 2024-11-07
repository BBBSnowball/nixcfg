{ ... }:
{
  systemd.watchdog.runtimeTime = "1min";
  systemd.watchdog.kexecTime = "10min";
  systemd.watchdog.rebootTime = "10min";
}
