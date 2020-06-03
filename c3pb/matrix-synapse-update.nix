self: super: let
  needsUpdate = super.matrix-synapse.version == "1.13.0";
  newAuthLib = self.python3.pkgs.authlib.overrideAttrs (old: old // rec {
    version = "0.14.3";
    src = self.fetchFromGitHub {
      owner = "lepture";
      repo = "authlib";
      rev = "v${version}";
      sha256 = "0ph97j94i40jj7nc5ya8pfq0ccx023zbqpcs5hrxmib53g64k5xy";
    };
  });
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
    propagatedBuildInputs = old.propagatedBuildInputs ++ [newAuthLib];
    patches = [
      ./matrix-synapse-patch-for-gitlab.patch
      ./matrix-synapse-patch-for-existing-users.patch
    ] ++ (old.patches or []);
    doCheck = false;
    doInstallCheck = false;
  });
in {
  matrix-synapse = if needsUpdate || true then newSynapse else super.matrix-synapse;
}
