{ pkgs, ... }:
let
  kvmStart = pkgs.writeShellScript "kvm-start.sh" ''
    #!/bin/bash -e
    INST=$1
    
    # memory setting seems to be ignored in config file so promote it to command line
    m=`sed -nr '/^\[memory\]\s*$/,/^\[/ s/^\s*size\s*=\s*\"?([^"]*)\"?\s*$/\1/p' "/var/vms/$INST.cfg"`
    if [ -z "$m" ] ; then m=128 ; fi
    
    exec /usr/bin/qemu-system-x86_64 \
            -enable-kvm -nographic -runas nobody -name "$INST" \
            -pidfile "/run/qemu/$INST.pid" \
            -monitor unix:/run/qemu/$INST.monitor,server,nowait \
            -serial unix:/run/qemu/$INST.serial,server,nowait \
            -m $m \
            -net none \
            -readconfig "/var/vms/$INST.cfg" \
            `sed -rn "s/#\s*EXTRA_ARGS:\s+//p" "/var/vms/$INST.cfg"`
  '';
in
{
  systemd.services."kvm@.service" = {
    # inspired by https://github.com/rafaelmartins/kvm-systemd/blob/master/systemd/system/kvm%40.service
    description = "Start virtual machine %I";
    wants = [ "network.target" ];
    after = [ "network.target" ];
    environment.INST = "%I";

    serviceConfig = {
      Type = "simple";
      PIDFile = "/run/qemu/%I.pid";
      TimeoutStopSec = "20";
      UMask = "077";
      RuntimeDirectory = "qemu";

      ExecStart = "${kvmStart} \"%I\"";
      #ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /run/qemu";

      ExecStop = "${pkgs.bash}/bin/bash -c \"( echo system_powerdown ; sleep 10 ) | socat -u STDIO UNIX-CONNECT:/run/qemu/%I.monitor,connect-timeout=5,linger=15 ; true\"";
    };

    postStart = ''
      ${pkgs.gnused}/bin/sed -rn "s/#\s*POST_START:\s+//p" /var/vms/$INST.cfg | bash -
    '';

    #TODO:
    #  1. Timeout for stop is ignored, i.e. VM is killed by SIGTERM.
    #     -> I don't have a good solution but `sleep 10` at least makes it wait for some time (it always waits for that long, though).
    #  2. Network connections to the VM don't work.
    #     -> qemu was adding its default network device as the first network device. -> add `-net none`
    #  3. Qemu ignores memory size in config file, so we have to specify it on commandline.
    #     -> some sed magic solves that one.
    #  4. Add -smp option (processor count).
    #     -> can be specified in config file
  };
}
