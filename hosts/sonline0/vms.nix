{ lib, pkgs, config, ... }:
let
  kvmStart = pkgs.writeShellScript "kvm-start.sh" ''
    #!/bin/bash -e
    INST=$1
    
    # memory setting seems to be ignored in config file so promote it to command line
    m=`sed -nr '/^\[memory\]\s*$/,/^\[/ s/^\s*size\s*=\s*\"?([^"]*)\"?\s*$/\1/p' "/var/vms/$INST.cfg"`
    if [ -z "$m" ] ; then m=128 ; fi
    
    exec qemu-system-x86_64 \
            -enable-kvm -nographic -runas nobody -name "$INST" \
            -pidfile "/run/qemu/$INST.pid" \
            -monitor unix:/run/qemu/$INST.monitor,server,nowait \
            -serial unix:/run/qemu/$INST.serial,server,nowait \
            -m $m \
            -net none \
            -readconfig "/var/vms/$INST.cfg" \
            `sed -rn "s/#\s*EXTRA_ARGS:\s+//p" "/var/vms/$INST.cfg"`
  '';

  kvmTemplateUnit = {
    # inspired by https://github.com/rafaelmartins/kvm-systemd/blob/master/systemd/system/kvm%40.service
    description = "Start virtual machine %I";
    wants = [ "network.target" ];
    after = [ "network.target" ];
    environment.INST = "%I";
    path = with pkgs; [ gnused bash qemu_kvm socat bridge-utils iproute2 ];

    # We usually don't want to reboot the VM when the service changes.
    stopIfChanged = false;
    restartIfChanged = false;

    serviceConfig = {
      Type = "simple";
      PIDFile = "/run/qemu/%I.pid";
      TimeoutStopSec = "20";
      UMask = "077";
      RuntimeDirectory = "qemu";
      RuntimeDirectoryPreserve = true;  # used by multiple service instances so don't delete when one is stopped
      RuntimeDirectoryMode = "0700";

      ExecStart = "${kvmStart} \"%I\"";
      #ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /run/qemu";

      ExecStop = "${pkgs.bash}/bin/bash -c \"( echo system_powerdown ; sleep 10 ) | socat -u STDIO UNIX-CONNECT:/run/qemu/%I.monitor,connect-timeout=5,linger=15 ; true\"";
    };

    postStart = ''
      sed -rn "s/#\s*POST_START:\s+//p" /var/vms/$INST.cfg | bash -
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

  # https://github.com/NixOS/nixpkgs/issues/80933#issuecomment-1295396500
  autoStartUnits = lib.genAttrs (builtins.map (name: "kvm@${name}") config.virtualisation.kvm.autoStart) (_: {
    wantedBy = [ "machines.target" ];
    overrideStrategy = "asDropin";
    # NixOS would override this, which we undo here.
    inherit (kvmTemplateUnit) path;
    # We usually don't want to reboot the VM when the service changes.
    stopIfChanged = false;
    restartIfChanged = false;
  });
in
{
  options = {
    virtualisation.kvm.autoStart = with lib; mkOption {
      default = [];
      type = with types; listOf str;
      description = "List of virtual machines (kvm@... units) to start after boot.";
    };
  };

  config.systemd.services = autoStartUnits // { "kvm@" = kvmTemplateUnit; };

  config.environment.etc = {
    "qemu-ifup-br84".source = pkgs.writeShellScript "qemu-ifup-br84" ''
      # Script to bring a network (tap) device for qemu up.
      # The idea is to add the tap device to the same bridge
      # as we have default routing to.
      
      # always use the same bridge
      br=br84
      
      ip link set "$1" up
      
      # We enable hairpin mode because we use hairpin DNAT so a packet may exit through the
      # same port that it came through if the VM tries to talk to itself via the external IP
      # (which is allowed and useful).
      #ip link set "$1" master "$br" hairpin on  # -> doesn't work
      ip link set "$1" master "$br"
      ip link set "$1" type bridge_slave hairpin on
    '';
    # Default scripts for qemu-ifdown - just as it is on Debian, i.e. doing nothing.
    # This must exist to avoid an error message when shutting down a VM.
    "qemu-ifdown".source = pkgs.writeShellScript "qemu-ifdown" ''
      # Script to shut down a network (tap) device for qemu.
      # Initially this script is empty, but you can configure,
      # for example, accounting info here.
      
      :
    '';
    # We don't add the qemu-ifup script because we will always use the one above.
    # Let's symlink it in case we forget to override it for a new VM.
    "qemu-ifup".source = "/etc/qemu-ifup-br84";
  };
}
