{ privateForHost, secretForHost, ... }:
{
  # Generate with: nix-store --generate-binary-cache-key fwa nix-store.secret nix-store.pub
  nix.settings = {
    secret-key-files = [
      #"${secretForHost}/nix-store.secret"
      "/etc/nixos/secret_local/nix-store.secret"
    ];
    extra-trusted-public-keys = [
      privateForHost.nix.pubkey
    ];
  };

  # We use a different key for nix-serve, for now.
  # Generate with: nix-store --generate-binary-cache-key fwa-serve nix-serve.secret nix-serve.pub
  # see https://nixos.wiki/wiki/Binary_Cache
  services.nix-serve = {
    enable = true;
    secretKeyFile = "/etc/nixos/secret_local/nix-serve.secret";
    port = 8082;
    openFirewall = false;  # We will do it manually when needed.
  };
}
