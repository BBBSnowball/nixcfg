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

        # We want flakes!
        nix.extraOptions = ''
          experimental-features = nix-command flakes
        '';

        systemd.services.nix-prepare = {
          description = "Create and mount /nix on Steam Deck";
          serviceConfig.BindPaths = "/:/real-root";
          path = [ pkgs.which config.nix.package pkgs.nix-info ];
          serviceConfig.Type = "oneshot";
          script = builtins.readFile ./files/nix-prepare.sh;
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

        # nix-channels seems to get its reply in /tmp in some cases, e.g. when called from nix-deck.service.
        systemd.services.nix-daemon.serviceConfig.BindPaths = [ "/tmp" ];

        # The systemd profile mounts machine-id and resolv.conf with BindReadOnlyPaths but that doesn't seem to
        # have any effect for nix-daemon. We can make it work by using BindPaths but then nix-daemon gets the
        # error ENOENT when trying to create a bind mount for resolv.conf in its sandbox. In fact, we will get the
        # same error if we do `touch /tmp/a; mount --bind /etc/resolv.conf /tmp/a`. Therefore, we mount it to a
        # different path and then copy it over.
        #FIXME This requires that the portable service is writable, which we would like to avoid if possible.
        #FIXME Terminate entr when the service terminates.
        systemd.services.nix-daemon.serviceConfig.BindReadOnlyPaths = [ "/etc/resolv.conf:/etc/resolv.conf2" ];
        systemd.services.nix-daemon.preStart = ''
          umount /etc/resolv.conf || true
          umount /etc/resolv.conf || true
          cp /etc/resolv.conf2 /etc/resolv.conf
          ( ${pkgs.entr}/bin/entr -n <<<"/etc/resolv.conf2" cp /etc/resolv.conf2 /etc/resolv.conf & )
        '';
      })
      ({ lib, ... }: {
        systemd = let
          deps = {
            requires = [ "nix-prepare.service" ];
            after = [ "nix-prepare.service" "nix.mount" ];
            wants = [ "nix.mount" ];
            unitConfig.RequiresMountsFor = lib.mkForce [ "/nix" "/nix/store" ];

            # don't enable nix-daemon by default because we enable our nix-deck service instead
            wantedBy = lib.mkForce [];
          };
          serviceDeps = deps // {
            serviceConfig.BindPaths = [ "/nix" ];
          };
        in {
          sockets.nix-daemon = deps;
          services.nix-daemon = serviceDeps;
          services.nix-gc = serviceDeps;
          services.nix-optimise = serviceDeps;
        };
      }) ];
    };

    packages.x86_64-linux = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
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
        units = [];
        symlinks = [
          { object = "${filterEtc etc "nix"}/etc/systemd"; symlink = "/etc/systemd2"; }
          { object = "${filterEtc etc "nix"}/etc/ssl"; symlink = "/etc/ssl"; }
          { object = "${filterEtc etc "nix"}/etc/nix"; symlink = "/etc/nix"; }
          #NOTE This should have an entry for all users that are expected to use nix. Otherwise, their profile directory
          #     will be named with the uid rather than the user name. I'm not sure whether this has any non-cosmetic consequences.
          { symlink = "/etc/passwd"; object = pkgs.writeText "passwd" ''
            root:x:0:0:System administrator:/root:/run/current-system/sw/bin/bash
            deck:x:1000:1000:Steam Deck User:/home/deck:/bin/bash
            ${with pkgs.lib; concatMapStringsSep "\n"
              (i: "nixbld${toString i}:x:${toString (30000+i)}:30000:Nix build user ${toString i}:/var/empty:/run/current-system/sw/bin/nologin")
              (range 1 32)}
            nobody:x:65534:65534:Unprivileged account (don't use!):/var/empty:/run/current-system/sw/bin/nologin
            ''; }
          { symlink = "/etc/group"; object = pkgs.writeText "group" ''
            root:x:0:
            nixbld:x:30000:${with pkgs.lib; concatMapStringsSep "," (i: "nixbld${toString i}") (range 1 32)}
            nogroup:x:65534:
            ''; }
        ];
      };
      default = portableServiceAsDir "nix" etc serviceSquashfs;
    };
  };
}
