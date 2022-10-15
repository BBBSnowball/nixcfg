# nix build . -L -o nix-deck && tar -cf nix-deck.tar nix-deck/* && rsync nix-deck.tar deck2: && ssh -t deck2 "sudo tar -xf ~deck/nix-deck.tar -C ~root && sudo portablectl attach ~root/nix-deck/nix -p trusted --enable && sudo systemctl start nix-deck.service"
# ssh deck2 nix-shell -p nix-info --run nix-info  # This needs download and local build to work so it is a good test.
# (We are not using `--now` for portablectl because that seems to start all services.)
# If you want to use it in existing shells, run this in each shell:
#   . ~/.nix-profile/etc/profile.d/nix.sh
# The root user tries to build without the daemon (which won't work) so we have to force it with NIX_REMOTE=daemon.
#
# also useful:
# - set a password with passwd to use sudo
# - systemctl enable --now sshd
# - systemd-inhibit --who=me --why=because_I_say_so --mode=block sleep inf
#
# Uninstall:
#   systemctl disable --now nix-deck.service
#   portablectl detach ~root/nix-deck/nix*
#   rm /opt/nix /etc/nix /etc/systemd/system/nix.mount /etc/profile.d/nix.sh ~root/nix-deck {~root,~deck}/{.nix-channels,.nix-defexpr,.nix-profile} -rf
#
#FIXME It would be nice if all/most of the files in the host point to /opt/nix/var/nix/profiles/nix-deck/... so we have a good way to update them. We don't have any suitable derivation in the portable service's Nix store yet and we cannot reattach the portable service to the new location from within the service (or while the service is running). We could have a nearly identical copy in the Nix store and then use a temporary service to do the reattaching (in /nix/store because that will be available without the portable service).
#FIXME Split this file. Make our own fork of nixpkgs' portableServices with support for extraCommands and different output formats rather than monkey-patching.
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {
    nixosConfigurations.deck = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ({ config, pkgs, lib, ... }: {
        networking.hostName = "deck";
        documentation.man.enable = false;
        #systemd.package = pkgs.systemdMinimal;
        nixpkgs.overlays = [ (self: super: {
          #NOTE We will have systemd anyway because it is added to every systemd.services.<name>.path by stage2ServiceConfig.
          #util-linux = super.util-linux.override { systemdSupport = false; systemd = null; };
        }) ];
        #nix.package = pkgs.pkgsStatic.nix.override { enableDocumentation = false; withAWS = false; };

        # We want flakes!
        #nix.package = pkgs.nixFlakes;
        nix.extraOptions = ''
          experimental-features = nix-command flakes
        '';

        systemd.services.nix-prepare = {
          description = "Create and mount /nix on Steam Deck";
          serviceConfig.BindPaths = "/:/real-root";
          path = [ pkgs.which config.nix.package pkgs.nix-info ];
          serviceConfig.Type = "oneshot";
          script = ''
            set -eo pipefail
            #set -x

            #if [ -e /real-root/opt/nix/nix.mount -a -e /real-root/nix/nix.mount ] ; then
            #  echo "/nix is already mounted"
            #  exit 0
            #fi

            # see https://github.com/NixOS/nix/blob/88a45d6149c0e304f6eb2efcc2d7a4d0d569f8af/scripts/install-multi-user.sh
            install -dv -m 0755 /real-root/opt/nix /real-root/opt/nix/var /real-root/opt/nix/var/log /real-root/opt/nix/var/log/nix /real-root/opt/nix/var/log/nix/drvs /real-root/opt/nix/var/nix{,/db,/gcroots,/profiles,/temproots,/userpool,/daemon-socket} /real-root/opt/nix/var/nix/{gcroots,profiles}/per-user
            install -dv -g nixbld -m 1775 /real-root/opt/nix/store
            install -dv -o 1000 -m 0755 /real-root/opt/nix/var/nix/{gcroots,profiles}/per-user/deck

            if [ ! -e /real-root/root/.nix-channels ] ; then
              echo "https://nixos.org/channels/nixpkgs-unstable nixpkgs" > "/tmp/.nix-channels"
              install -m 0664 "/tmp/.nix-channels" "/real-root/root/.nix-channels"
            fi

            for src in /nix/store/* ; do
              dst="/real-root/opt$src"
              tmp="$dst.tmp$$"
              rm -rf "$tmp"
              if [ ! -e "$dst" ] ; then
                cp -RPp "$src" "$tmp"
                chmod -R a-w "$tmp"
                mv -T "$tmp" "$dst"
              fi
            done

            # We need the group nixbld outside of our service, e.g. nix-channel needs it.
            #FIXME This will replace /etc/group with a file in the overlay, i.e. we will miss future changes in the base image!
            #      -> Try to use a dynamic user+group.
            #      -> Doesn't seem to be required if we force root to use the daemon (which we want to do anyway).
            #chroot /real-root /usr/bin/groupadd -g 30000 nixbld || true

            #FIXME We would like to make a profile that points to the rootfs of the portable service in our nix store but that would
            #      be a circular dependency. Maybe we want a host config without the nix-prepare service and then use that..?
            #chroot /real-root $(which nix-env) -p /nix/var/nix/profiles/nix-service --set ...
            if [ ! -e /real-root/etc/nix ] ; then
              cp -dRLT /etc/nix /real-root/etc/nix
            fi

            # Add profile script to shell profile.
            if [ ! -e /real-root/etc/profile.d/nix.sh ] ; then
              #FIXME This should also be a symlink.
              cat >/real-root/etc/profile.d/nix.sh <<"EOF"
              # added by nix-deck portable service
              export NIX_REMOTE=daemon
              if [ -r "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; fi
              EOF
            fi

            # Trick 1: A mount in the service would only be visible to us but we can tell systemd to do the mount for us.
            cat >/real-root/opt/nix/nix.mount <<"EOF"
            [Unit]
            Description=Nix Store
            Before=nix-daemon.service nix-gc.service nix-optimise.service
            
            [Mount]
            Where=/nix
            What=/opt/nix
            Type=none
            Options=bind

            #[Install]
            #WantedBy=local-fs.target
            EOF
            # I think this is ignored by systemd because the symlink is broken when it reads the files (because /opt isn't mounted at that time).
            #ln -sfT /opt/nix/nix.mount /real-root/etc/systemd/system/nix.mount
            cp /real-root/opt/nix/nix.mount /real-root/etc/systemd/system/nix.mount

            # Trick 2: systemctl will refuse to work in chroot - unless that chroot is identical to the main root fs.
            chroot /real-root /usr/bin/systemctl daemon-reload
            chroot /real-root /usr/bin/systemctl start nix.mount

            # This cannot work yet because /nix is not mounted in /real-root, yet - if we are on a fresh install. It isn't necessary anyway.
            #if [ ! -e /real-root/opt/nix/var/nix/db/db.sqlite ] ; then
            #  chroot /real-root $(which nix-store) --verify
            #fi

            set +x
          '';
        };

        systemd.services.nix-debug = {
          description = "Run `sleep inf` so the user can use attach with nsenter";
          serviceConfig.BindPaths = "/:/real-root";
          inherit (config.systemd.services.nix-prepare) path;
          script = ''sleep inf'';
        };

        systemd.services.nix-deck = {
          description = "Initial setup for Nix on Steam Deck";
          serviceConfig.BindPaths = [ "/:/real-root" "/tmp" "/nix" ];
          path = [ pkgs.which config.nix.package pkgs.nix-info ];
          serviceConfig.Type = "oneshot";
          requires = [ "nix-daemon.service" ];  #FIXME Can we make it work with the socket? This has caused circular dependencies before so maybe not.
          #requires = [ "nix-prepare.service" "nix-daemon.socket" ];
          after = [ "nix-prepare.service" "nix-daemon.socket" ];
          wantedBy = [ "multi-user.target" ];

          script = ''
            # This needs nix-daemon so we cannot do it in nix-prepare.service.
            set -x

            # Update channels for root.
            if [ -e /real-root/root/.nix-channels -a ! -e /real-root/nix/var/nix/profiles/per-user/root/channels ] ; then
              NIX_REMOTE=daemon chroot /real-root $(which nix-channel) --update \
                || ( sleep 5 && NIX_REMOTE=daemon chroot /real-root $(which nix-channel) --update )
            fi

            # Create a profile for the user deck.
            if [ ! -e ~deck/.nix-profile ] ; then
              chroot /real-root /usr/bin/su deck -c "$(which nix-env) -iA nixpkgs.nix"
            fi
          '';
        };

        systemd.sockets.nix-daemon.requires = [ "nix-prepare.service" ];
        systemd.sockets.nix-daemon.after = [ "nix-prepare.service" "nix.mount" ];
        systemd.sockets.nix-daemon.wants = [ "nix.mount" ];
        systemd.services.nix-daemon.requires = [ "nix-prepare.service" ];
        systemd.services.nix-daemon.after = [ "nix-prepare.service" "nix.mount" ];
        systemd.services.nix-daemon.wants = [ "nix.mount" ];
        systemd.services.nix-daemon.unitConfig.RequiresMountsFor = lib.mkForce [ "/nix" "/nix/store" ];
        systemd.services.nix-gc.requires = [ "nix-prepare.service" ];
        systemd.services.nix-gc.after = [ "nix-prepare.service" ];
        systemd.services.nix-optimise.requires = [ "nix-prepare.service" ];
        systemd.services.nix-optimise.after = [ "nix-prepare.service" ];
        # nix-channels seems to get its reply in /tmp in some cases, e.g. when called from nix-deck.service.
        systemd.services.nix-daemon.serviceConfig.BindPaths = [ "/nix" "/tmp" ];
        systemd.services.nix-gc.serviceConfig.BindPaths = [ "/nix" ];
        systemd.services.nix-optimise.serviceConfig.BindPaths = [ "/nix" ];
        # This is supposed to be set by the profile and it is - but it doesn't work.
        #systemd.services.nix-daemon.serviceConfig.BindReadOnlyPaths = [ "/etc/machine-id" "/etc/resolv.conf" ];
        # -> Adding it to r/w path works but that really isn't the correct solution...
        #systemd.services.nix-daemon.serviceConfig.BindPaths = [ "/nix" "/etc/machine-id" "/etc/resolv.conf" ];
        systemd.services.nix-daemon.serviceConfig.BindReadOnlyPaths = [ "/etc/resolv.conf:/etc/resolv.conf2" ];
        systemd.services.nix-daemon.preStart = ''
          umount /etc/resolv.conf || true
          umount /etc/resolv.conf || true
          cp /etc/resolv.conf2 /etc/resolv.conf
          ( ${pkgs.entr}/bin/entr -n <<<"/etc/resolv.conf2" cp /etc/resolv.conf2 /etc/resolv.conf & )
        '';

        # don't enable nix-daemon by default because we enable our nix-deck service instead
        systemd.sockets.nix-daemon.wantedBy = lib.mkForce [];
        systemd.services.nix-daemon.wantedBy = lib.mkForce [];
      }) ];
    };

    packages.x86_64-linux = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      retrieveServiceFile = etc: name: pkgs.runCommand name {} ''
        #mkdir -p "$(dirname "$out/etc/systemd/system/${name}")"
        #cp "${etc}/etc/systemd/system/${name}" "$out/etc/systemd/system/${name}"
        cp "${etc}/etc/systemd/system/${name}" $out
      '';
      filterEtc = etc: name: pkgs.runCommand "${name}-etc" { inherit name; } ''
        mkdir -p $out/etc/systemd/system
        # We copy with `-L` because systemd will read the files outside of the portable service
        # environment, i.e. symlinks with absolute paths won't work.
        cp -dRL ${etc}/etc/systemd/system/"$name"* $out/etc/systemd/system/
        for x in /etc/ssl /etc/nix ; do
          cp -dRTL ${etc}$x $out$x
        done

        # NixOS doesn't populate the [Install] section and creates bla.target.wants symlinks instead.
        # This is good for stateless configuration but not useful for our portable service.
        #
        # First, remove existing [Install] sections that might be present for units that have been
        # copied from a package rather than generated by NixOS.
        grep -lri '\[Install\]' $out/etc/systemd/system/ | while read x ; do
          sed -bi '/^\[Install\]/,/^\[/ { /^\[Install\]/ d; /^[^\[]/ d }' "$x"
        done

        # Now, find relevant symlinks and add [Install] info for them.
        for x in ${etc}/etc/systemd/system/*.wants/"${name}"* ; do
          unit="''${x##*/}"
          x2="''${x%.wants/*}"
          target="''${x2##*/}"
          chmod +w $out/etc/systemd/system/"$unit"
          echo '[Install]' >>$out/etc/systemd/system/"$unit"
          echo "# from $x" >>$out/etc/systemd/system/"$unit"
          echo "WantedBy=$target" >>$out/etc/systemd/system/"$unit"
        done
      '';
      portableServiceAsDir = pname: etc: drv: pkgs.stdenv.mkDerivation rec {
        inherit pname;
        inherit (drv) version name closureInfo;
        # closureInfo is taken from the squashfs derivation, which generates it like this:
        #closureInfo = pkgs.closureInfo { rootPaths = [ rootFsScaffold ] ++ contents; };

        # We also need rootFsScaffold and that is more tricky to get.
        rootFsScaffold = (drv.closureInfo.overrideAttrs (x: { passthru.rootFsScaffold = builtins.elemAt x.exportReferencesGraph.closure 0; })).rootFsScaffold;

        buildCommand = ''
          #mkdir -p "$out/${pname}_${version}"
          #cd "$out/${pname}_${version}"
          mkdir -p "$out/${pname}"
          cd "$out/${pname}"
          mkdir -p nix/store
          for i in $(< $closureInfo/store-paths); do
            cp -a "$i" "''${i:1}"
          done
          cp -r $rootFsScaffold/* .

          mkdir ./real-root

          #FIXME do this in a way that also works for the squashfs version!
          #mkdir -p ./etc/systemd/system
          #chmod +w ./etc/systemd/system
          #cp -dR ${etc}/etc/systemd/system/nix* ./etc/systemd/system/
          chmod +w ./etc/systemd ./etc
          rmdir ./etc/systemd/system ./etc/systemd
          cp -dLR ./etc/systemd2 ./etc/systemd
          rm -rf ./etc/systemd2

          # NixOS likes to use overrides but systemd would ignore them for a portable service so let's merge them.
          chmod +w ./etc/systemd/system
          for x in ./etc/systemd/system/* ; do
            if [ -e "$x.d" ] ; then
              chmod +w "$x" "$x.d"
              for y in "$x.d"/*.conf ; do
                echo "" >>"$x"
                echo "# $y" >>"$x"
                cat "$y" >>"$x"
                rm "$y"
              done
              rmdir "$x.d"
            fi
          done
        '';
      };
    in rec {
      host = self.nixosConfigurations.deck.config.system.build.toplevel;
      etc = self.nixosConfigurations.deck.config.system.build.etc;
      serviceSquashfs = pkgs.portableService {
        pname = "nix";
        version = pkgs.nix.version;
        description = "Nix packaged as a portable service for Steam Deck";
        units = [
          #(retrieveServiceFile etc "nix-daemon.service")
        ];
        symlinks = [
          #{ object = "-f ${etc}/etc/systemd"; symlink = "/etc/systemd"; }
          { object = "${filterEtc etc "nix"}/etc/systemd"; symlink = "/etc/systemd2"; }
          { object = "${filterEtc etc "nix"}/etc/ssl"; symlink = "/etc/ssl"; }
          { object = "${filterEtc etc "nix"}/etc/nix"; symlink = "/etc/nix"; }
          #NOTE This should have an entry for all users that are expected to use nix. Otherwise, their profile directory
          #     will be named with the uid rather than the user name. I'm not sure whether this has any non-cosmetic consequences.
          { symlink = "/etc/passwd"; object = pkgs.writeText "passwd" ''
            root:x:0:0:System administrator:/root:/run/current-system/sw/bin/bash
            deck:x:1000:1000:Steam Deck User:/home/deck:/bin/bash
            nixbld1:x:30001:30000:Nix build user 1:/var/empty:/run/current-system/sw/bin/nologin
            nixbld2:x:30002:30000:Nix build user 2:/var/empty:/run/current-system/sw/bin/nologin
            nixbld3:x:30003:30000:Nix build user 3:/var/empty:/run/current-system/sw/bin/nologin
            nixbld4:x:30004:30000:Nix build user 4:/var/empty:/run/current-system/sw/bin/nologin
            nixbld5:x:30005:30000:Nix build user 5:/var/empty:/run/current-system/sw/bin/nologin
            nixbld6:x:30006:30000:Nix build user 6:/var/empty:/run/current-system/sw/bin/nologin
            nixbld7:x:30007:30000:Nix build user 7:/var/empty:/run/current-system/sw/bin/nologin
            nixbld8:x:30008:30000:Nix build user 8:/var/empty:/run/current-system/sw/bin/nologin
            nixbld9:x:30009:30000:Nix build user 9:/var/empty:/run/current-system/sw/bin/nologin
            nixbld10:x:30010:30000:Nix build user 10:/var/empty:/run/current-system/sw/bin/nologin
            nixbld11:x:30011:30000:Nix build user 11:/var/empty:/run/current-system/sw/bin/nologin
            nixbld12:x:30012:30000:Nix build user 12:/var/empty:/run/current-system/sw/bin/nologin
            nixbld13:x:30013:30000:Nix build user 13:/var/empty:/run/current-system/sw/bin/nologin
            nixbld14:x:30014:30000:Nix build user 14:/var/empty:/run/current-system/sw/bin/nologin
            nixbld15:x:30015:30000:Nix build user 15:/var/empty:/run/current-system/sw/bin/nologin
            nixbld16:x:30016:30000:Nix build user 16:/var/empty:/run/current-system/sw/bin/nologin
            nixbld17:x:30017:30000:Nix build user 17:/var/empty:/run/current-system/sw/bin/nologin
            nixbld18:x:30018:30000:Nix build user 18:/var/empty:/run/current-system/sw/bin/nologin
            nixbld19:x:30019:30000:Nix build user 19:/var/empty:/run/current-system/sw/bin/nologin
            nixbld20:x:30020:30000:Nix build user 20:/var/empty:/run/current-system/sw/bin/nologin
            nixbld21:x:30021:30000:Nix build user 21:/var/empty:/run/current-system/sw/bin/nologin
            nixbld22:x:30022:30000:Nix build user 22:/var/empty:/run/current-system/sw/bin/nologin
            nixbld23:x:30023:30000:Nix build user 23:/var/empty:/run/current-system/sw/bin/nologin
            nixbld24:x:30024:30000:Nix build user 24:/var/empty:/run/current-system/sw/bin/nologin
            nixbld25:x:30025:30000:Nix build user 25:/var/empty:/run/current-system/sw/bin/nologin
            nixbld26:x:30026:30000:Nix build user 26:/var/empty:/run/current-system/sw/bin/nologin
            nixbld27:x:30027:30000:Nix build user 27:/var/empty:/run/current-system/sw/bin/nologin
            nixbld28:x:30028:30000:Nix build user 28:/var/empty:/run/current-system/sw/bin/nologin
            nixbld29:x:30029:30000:Nix build user 29:/var/empty:/run/current-system/sw/bin/nologin
            nixbld30:x:30030:30000:Nix build user 30:/var/empty:/run/current-system/sw/bin/nologin
            nixbld31:x:30031:30000:Nix build user 31:/var/empty:/run/current-system/sw/bin/nologin
            nixbld32:x:30032:30000:Nix build user 32:/var/empty:/run/current-system/sw/bin/nologin
            nobody:x:65534:65534:Unprivileged account (don't use!):/var/empty:/run/current-system/sw/bin/nologin
            ''; }
          { symlink = "/etc/group"; object = pkgs.writeText "group" ''
            root:x:0:
            nixbld:x:30000:nixbld1,nixbld10,nixbld11,nixbld12,nixbld13,nixbld14,nixbld15,nixbld16,nixbld17,nixbld18,nixbld19,nixbld2,nixbld20,nixbld21,nixbld22,nixbld23,nixbld24,nixbld25,nixbld26,nixbld27,nixbld28,nixbld29,nixbld3,nixbld30,nixbld31,nixbld32,nixbld4,nixbld5,nixbld6,nixbld7,nixbld8,nixbld9
            nogroup:x:65534:
            ''; }
        ];
      };
      default = portableServiceAsDir "nix" etc serviceSquashfs;
    };
  };
}
