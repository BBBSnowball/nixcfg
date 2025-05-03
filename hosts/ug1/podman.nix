{ pkgs, ... }:
{
  virtualisation = {
    containers.enable = true;

    podman = {
      enable = true;
      dockerSocket.enable = true;  # socket alias
      dockerCompat = true;  # command alias
      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  # This effectively makes these users root but they are in wheel anyway.
  users.users.user.extraGroups = [ "podman" ];

  users.users.user.packages = with pkgs; [
    dive # look into docker image layers
    podman-tui # status of containers in the terminal
    docker-compose # start group of containers for dev
    podman-compose # start group of containers for dev
  ];

  # look in Docker registry by default
  virtualisation.containers.registries.search = [
    "docker.io"
    "quay.io"  # also present in NixOS' default
    # -> keep both of them, so podman will ask which one should be used
  ];
}
