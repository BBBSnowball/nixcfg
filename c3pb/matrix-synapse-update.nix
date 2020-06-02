self: super: let
  needsUpdate = super.matrix-synapse.version == "1.13.0";
  newSynapse = super.matrix-synapse.overrideAttrs (old: old // rec {
    # We need Synapse 1.14.0 for OpenID Connect. This is already available in master:
    # https://github.com/NixOS/nixpkgs/commit/d11dcafe93208d4de3cb837f18b735db3c343efb
    version = "1.14.0";
    name = "${old.pname}-${version}";
    src = self.python3.pkgs.fetchPypi {
      inherit (old) pname;
      inherit version;
      sha256 = "09drdqcjvpk9s3hq5rx9yxsxq0wak5fg5gfaiqfnbnxav2c2v7kq";
    };
    propagatedBuildInputs = old.propagatedBuildInputs ++ [self.python3.pkgs.authlib];
  });
in {
  matrix-synapse = if needsUpdate then newSynapse else super.matrix-synapse;
}
