# A profile with most (vanilla) hardening options enabled by default,
# potentially at the cost of stability, features and performance.
#
# This profile enables options that are known to affect system
# stability. If you experience any stability issues when using the
# profile, try disabling it. If you report an issue and use this
# profile, always mention that you do.
#
# This is based on NixOS' module:
# https://github.com/NixOS/nixpkgs/raw/refs/heads/nixos-25.11/nixos/modules/profiles/hardened.nix

{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkOverride
    mkEnableOption
    mkIf
    maintainers
    ;

  # NixOS had the kernel with these patches, which we omit here:
  # https://github.com/anthraxx/linux-hardened
  linux_hardened = pkgs.linuxPackagesFor (pkgs.linuxPackages.kernel.override {
    structuredExtraConfig = import ./kernel-config.nix {
      inherit lib;
      inherit (pkgs) stdenv;
      inherit (pkgs.linuxPackages.kernel) version;
    };
    argsOverride = {
      pname = "linux-hardened";
    };
    isHardened = true;
  });
in
{
  config = {
    #boot.kernelPackages = mkDefault pkgs.linuxKernel.packages.linux_hardened;
    #boot.kernelPackages = mkDefault linux_hardened;

    #nix.settings.allowed-users = mkDefault [ "@users" ];  # -> already defined in common.nix

    # https://source.android.com/docs/security/test/scudo
    # https://llvm.org/docs/ScudoHardenedAllocator.html
    # -> crashes redis (segfault) and edumeet (mismatch in library versions)
    #environment.memoryAllocator.provider = mkDefault "scudo";
    #environment.variables.SCUDO_OPTIONS = mkDefault "zero_contents=true";

    #security.lockKernelModules = mkDefault true;

    #security.protectKernelImage = mkDefault true;

    #security.allowSimultaneousMultithreading = mkDefault false;

    #security.forcePageTableIsolation = mkDefault true;

    # This is required by podman to run containers in rootless mode.
    #security.unprivilegedUsernsClone = mkDefault config.virtualisation.containers.enable;

    # Let's keep user namespaces enabled, for now.
    # see https://discourse.nixos.org/t/proposal-to-deprecate-the-hardened-profile/63081/5
    # (We are not a desktop system but there are other good uses, e.g. containers and systemd services might use it.)
    security.allowUserNamespaces = true;
    security.unprivilegedUsernsClone = true;

    #security.virtualisation.flushL1DataCache = mkDefault "always";

    #security.apparmor.enable = mkDefault true;
    #security.apparmor.killUnconfinedConfinables = mkDefault true;

    boot.kernelParams = [
      # Don't merge slabs
      "slab_nomerge"

      # Overwrite free'd pages
      "page_poison=1"

      # Enable page allocator randomization
      "page_alloc.shuffle=1"

      # Disable debugfs
      "debugfs=off"
    ];

    boot.blacklistedKernelModules = [
      # Obscure network protocols
      "ax25"
      "netrom"
      "rose"

      # Old or rare or insufficiently audited filesystems
      "adfs"
      "affs"
      "bfs"
      "befs"
      "cramfs"
      "efs"
      "erofs"
      "exofs"
      "freevxfs"
      "f2fs"
      "hfs"
      "hpfs"
      "jfs"
      "minix"
      "nilfs2"
      "ntfs"
      "omfs"
      "qnx4"
      "qnx6"
      "sysv"
      "ufs"

      # https://copy.fail / CVE-2026-31431
      # (some crypto operations in userspace might be a bit slower)
      "algif_aead"

      # dirty frag, CVE-2026-43284, https://github.com/V4bel/dirtyfrag
      # ESP: https://www.ietf.org/rfc/rfc2406.txt
      # RXRPC: https://docs.kernel.org/networking/rxrpc.html
      "esp4"
      "esp6"
      "rxrpc"
    ];

    # Hide kptrs even for processes with CAP_SYSLOG
    boot.kernel.sysctl."kernel.kptr_restrict" = mkOverride 500 2;

    # Disable bpf() JIT (to eliminate spray attacks)
    #boot.kernel.sysctl."net.core.bpf_jit_enable" = mkDefault false;

    # Disable ftrace debugging
    boot.kernel.sysctl."kernel.ftrace_enabled" = mkDefault false;

    # Enable strict reverse path filtering (that is, do not attempt to route
    # packets that "obviously" do not belong to the iface's network; dropped
    # packets are logged as martians).
    #boot.kernel.sysctl."net.ipv4.conf.all.log_martians" = mkDefault true;
    #boot.kernel.sysctl."net.ipv4.conf.all.rp_filter" = mkDefault "1";
    #boot.kernel.sysctl."net.ipv4.conf.default.log_martians" = mkDefault true;
    #boot.kernel.sysctl."net.ipv4.conf.default.rp_filter" = mkDefault "1";

    # Ignore broadcast ICMP (mitigate SMURF)
    boot.kernel.sysctl."net.ipv4.icmp_echo_ignore_broadcasts" = mkDefault true;

    # Ignore incoming ICMP redirects (note: default is needed to ensure that the
    # setting is applied to interfaces added after the sysctls are set)
    boot.kernel.sysctl."net.ipv4.conf.all.accept_redirects" = mkDefault false;
    boot.kernel.sysctl."net.ipv4.conf.all.secure_redirects" = mkDefault false;
    boot.kernel.sysctl."net.ipv4.conf.default.accept_redirects" = mkDefault false;
    boot.kernel.sysctl."net.ipv4.conf.default.secure_redirects" = mkDefault false;
    boot.kernel.sysctl."net.ipv6.conf.all.accept_redirects" = mkDefault false;
    boot.kernel.sysctl."net.ipv6.conf.default.accept_redirects" = mkDefault false;

    # Ignore outgoing ICMP redirects (this is ipv4 only)
    boot.kernel.sysctl."net.ipv4.conf.all.send_redirects" = mkDefault false;
    boot.kernel.sysctl."net.ipv4.conf.default.send_redirects" = mkDefault false;
  };
}
