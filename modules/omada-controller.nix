{ config, pkgs, lib, ... }:
let
  omadaControllerOverlay = self: super: { omada-controller = self.callPackage ../pkgs/omada-controller.nix {}; };
  conf = config.services.omada-controller;
  name = "omada-controller";
  #chosen_jre = pkgs.jre8;
  chosen_jre = pkgs.openjdk;
in {
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

  config.systemd.services.omada-controller = {
    description = "Omada Software Controller that controls Omada WiFi access points and SDN switches";
    path = with pkgs; [ omada-controller curl jsvc chosen_jre bash procps ];

    serviceConfig.StateDirectory = name;
    serviceConfig.LogsDirectory = name;
    serviceConfig.RuntimeDirectory = name;

    environment = {
      #OMADA_HOME = conf.package.outPath;
      OMADA_PKG = conf.package.outPath;
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
    serviceConfig.DynamicUser = "yes";
    #serviceConfig.User = name;
  };

  # Ports:
  # 27217: mongodb. no ACL so never open this to the network.
  # 29811-29814: ?
  # 8088: HTTP port for management
  # 8843: HTTPS for portal
  # 8043: HTTPS for management
  # UDP:
  # 29810: Controller Inform Port
  # 27001: ??

  config.networking.firewall.allowedTCPPorts = [ 29811 29812 29813 29814 8088 8043 8843 ];
  config.networking.firewall.allowedUDPPorts = [ 29810 27001 ];
}
