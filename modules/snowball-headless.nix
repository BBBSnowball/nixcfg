{ lib, config, modules, ... }:
{
  imports = [
    modules.common
  ];

  services.openssh.enable = true;

  # https://github.com/NixOS/nixpkgs/pull/156750
  # https://www.bleepingcomputer.com/news/security/linux-system-service-bug-gives-root-on-all-major-distros-exploit-released/
  # Not that I really need too many reasons to not enable polkit unless there is a good reason for it but this is plenty ^^
  # Priority 60 is a bit less than mkForce. X11 insists that we need Polkit so only disable it if X11 is not enabled.
  security.polkit.enable = lib.mkIf (!config.services.xserver.enable) (lib.mkOverride 60 false);
}
