self: super: {
  matrix-synapse = super.matrix-synapse.overrideAttrs (old: old // rec {
    patches = [
      ./matrix-synapse-patch-for-gitlab.patch
      ./matrix-synapse-patch-for-existing-users.patch
    ] ++ (old.patches or []);
    doCheck = false;
    doInstallCheck = false;
  });
}
