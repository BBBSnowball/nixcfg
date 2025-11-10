{ config, pkgs, lib, routeromen, ... }:
let
  nixpkgs-mongodb = routeromen.inputs.nixpkgs-mongodb;

  omadaControllerOverlay = self: super: rec {
    # Hydra doesn't build new MongoDB because SSPL has more restrictions than AGPL and the build takes for ages.
    # Also, it seems that Omada wants the old version anyway.
    # -> It's not the best idea to pin this but we don't have any other good option, I think.
    #mongodb-for-omada = nixpkgs-mongodb.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mongodb;
    # Omada needs the new version, now. D'oh!
    # -> It seems that MongoDB is available on Hydra. Nice!
    # -> Too new for old database (but MongoDB 3.4 cannot open it either).
    # -> move data dir and setup anew from backup
    mongodb-for-omada = pkgs.mongodb.overrideAttrs (old: { meta = old.meta // { license=[]; }; });

    omada-controller = self.callPackage ../pkgs/omada-controller.nix {
      mongodb = mongodb-for-omada;
    };
  };

  conf = config.services.omada-controller;
  name = "omada-controller";
  #chosen_jre = pkgs.jre8;
  chosen_jre = pkgs.openjdk;
in {
  #imports = [ routeromen.nixosModules.allowUnfree ];  # -> infinite recursion
  imports = [ ./allowUnfree.nix ];

  options.services.omada-controller = with lib; {
    enable = mkEnableOption "Whether to enable Omada Software Controller";
    package = mkOption {
      type = types.package;
      default = pkgs.omada-controller;
      defaultText = literalExpression "pkgs.omada-controller";
      description = ''
        The package to use for the Omada Software Controller service.
      '';
    };
  };

  config.nixpkgs.overlays = [ omadaControllerOverlay ];
  config.nixpkgs.allowUnfreeByName = [ "mongodb" ];

  config.systemd.services.omada-controller = {
    description = "Omada Software Controller that controls Omada WiFi access points and SDN switches";
    path = with pkgs; [ omada-controller curl jsvc chosen_jre bash procps ];

    serviceConfig.StateDirectory = name;
    serviceConfig.LogsDirectory = name;
    serviceConfig.RuntimeDirectory = name;

    environment = {
      #OMADA_HOME = conf.package.outPath;
      OMADA_PKG = conf.package.outPath;
      OMADA_VERSION = conf.package.version;
      OMADA_HOME = "/var/lib/${name}";
      LOG_DIR = "/var/log/${name}";
      WORK_DIR = "/run/${name}";
      DATA_DIR = "/var/lib/${name}/data";
      PROPERTY_DIR = "/var/lib/${name}/properties";
      AUTOBACKUP_DIR = "/var/lib/${name}/data/autobackup";
      #JRE_HOME = chosen_jre;
      JAVA_TOOL = "${chosen_jre}/bin/java";
      JAVA_OPTS = "-server -Xms128m -Xmx1024m -XX:MaxHeapFreeRatio=60 -XX:MinHeapFreeRatio=30  -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/var/log/${name}/java_heapdump.hprof -Djava.awt.headless=true";
      MAIN_CLASS = "com.tplink.smb.omada.starter.OmadaLinuxMain";
      OMADA_USER = name;
      OMADA_GROUP = name;
      PID_FILE = "/run/${name}/${name}.pid";
      HTTP_PORT = "8088";
    };

    #http_code=$(curl -I -m 10 -o /dev/null -s -w %{http_code} http://localhost:${HTTP_PORT}/actuator/linux/check)

    script = ''
      # Check whether we are starting an older or newer version than before.
      if [ -e $OMADA_HOME/current-version ] ; then
        old_version="$(cat $OMADA_HOME/current-version)"
        if [ "$old_version" != "$OMADA_VERSION" ] ; then
          # idea for how to compare the versions is from here: https://github.com/mbentley/docker-omada-controller/pull/229/files#diff-edf4d034db059e72b5f6260af6d16b2194c6e733649071d376595ebc9f6d8ce1R210
          newer_version="$(printf '%s\n' "$old_version" "$OMADA_VERSION" | sort -rV | head -n1)"
          if [ "$newer_version" != "$OMADA_VERSION" ] ; then
            echo "ERROR: Current version of omada-controller is '$OMADA_VERSION' but this directory has previously been used with version '$old_version'. Refusing to downgrad because that may break this instance." >&2
            echo "See https://community.tp-link.com/en/business/forum/topic/577334 and https://github.com/mbentley/docker-omada-controller/issues/228" >&2
            echo "A backup of the old data may be available in $OMADA_HOME-backup-*" >&2
            exit 1
          fi

          #NOTE This is not ideal but we cannot write outside of our state directory at this point.
          backupdir="''${OMADA_HOME}/backup-$old_version"
          echo "Making backup because we are upgrading from $old_version to $OMADA_VERSION. Backup destination is $backupdir ..."
          if [ -e "$backupdir" ] ; then
            echo "ERROR: Backup directory already exists!" >&2
            exit 1
          fi
          ( umask 077 && mkdir $backupdir && cp -r $DATA_DIR/ $backupdir/ )
        fi
      fi
      echo "$OMADA_VERSION" >$OMADA_HOME/current-version

      mkdir -p $DATA_DIR/autobackup
      cp -rf $OMADA_PKG/data/* $DATA_DIR/
      chmod -R u+w $DATA_DIR

      # maybe don't do this every time..?
      mkdir -p $PROPERTY_DIR
      cp -rf $OMADA_PKG/properties/* $PROPERTY_DIR/

      ln -sfT $LOG_DIR $OMADA_HOME/logs
      if false; then
        ln -sfT $OMADA_PKG/lib $OMADA_HOME/lib
      elif false; then
        rm -rf $OMADA_HOME/lib
        mkdir -p $OMADA_HOME/lib
        for x in $OMADA_PKG/lib/* ; do ln -s $x $OMADA_HOME/lib/ ; done
      else
        # looks like OmadaBootstrap is too "intelligent" when looking for the keystore so let's copy stuff...
        # It would be so much easier if they just used the environment variables that they setup in their control.sh script.
        chmod -R u+w $OMADA_HOME/lib || true
        rm -rf $OMADA_HOME/lib
        cp -r $OMADA_PKG/lib $OMADA_HOME/lib
        ln -sfT $OMADA_PKG/bin $OMADA_HOME/bin
      fi
      cd $DATA_DIR
      exec java \
        -cp /usr/share/java/commons-daemon.jar:$OMADA_HOME/lib/*:$PROPERTY_DIR \
        --add-exports java.base/sun.util=ALL-UNNAMED \
        --add-opens=java.base/sun.security.util=ALL-UNNAMED \
        --add-opens=java.base/sun.security.x509=ALL-UNNAMED \
        $MAIN_CLASS start
    '';

    wantedBy = [ "multi-user.target" ];
    #serviceConfig.DynamicUser = "yes";
    serviceConfig.User = name;  # -> easier for debugging permission issues
  };

  config.users.users.${name} = {
    isSystemUser = true;
    group = "omada-controller";
  };
  config.users.groups.omada-controller = {};

  # Ports:
  # 27217: mongodb. no ACL so never open this to the network.
  # 29811-29817: ?  ("To ensure new device features work properly, ensure that devices can connect to TCP port 29817 on the Controller.")
  # 8088: HTTP port for management
  # 8843: HTTPS for portal
  # 8043: HTTPS for management
  # UDP:
  # 29810: Controller Inform Port
  # 27001: ??

  config.networking.firewall.allowedTCPPorts = [ 29811 29812 29813 29814 29815 29816 29817 8088 8043 8843 ];
  config.networking.firewall.allowedUDPPorts = [ 29810 27001 ];
}
