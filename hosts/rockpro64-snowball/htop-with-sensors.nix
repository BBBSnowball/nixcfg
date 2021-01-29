{ system, nixpkgs-unstable, ... }:
self: super: {
  # 20.09 has htop 3.0.2, which doesn't have sensors support.
  # htop 3.0.5 uses `--with-sensors` but master has switched to `--enable-sensors`.
  htop = nixpkgs-unstable.legacyPackages.${system}.htop.overrideAttrs (old: {
    configureFlags = [ "--with-sensors" "--enable-sensors" ];
    buildInputs = old.buildInputs ++ [ self.lm_sensors ];
  });
}
