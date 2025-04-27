{ system ? "x86_64-linux", pkgs ? import <nixpkgs> {}, python ? pkgs.python312, lib ? pkgs.lib }:
with (import ./uv2nix.nix { inherit pkgs; });
let
in
rec {
  src = pkgs.fetchFromGitHub {
    owner = "caltechads";
    repo = "nginx-ldap-auth-service";
    rev = "2.1.5";
    hash = "sha256-JRqYV1ZOUJX2WwrReZ8ljxk33XpHmXme2sKIJPLiO6o=";
  };

  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = src.outPath; };

  # see https://pyproject-nix.github.io/uv2nix/usage/hello-world.html
  overlay = workspace.mkPyprojectOverlay {
    # Binary wheels are more likely to, but may still require overrides for library dependencies.
    sourcePreference = "wheel"; # or sourcePreference = "sdist";
  };

  pyprojectOverrides = final: prev: {
    bonsai = prev.bonsai.overrideAttrs (old: {
      buildInputs = (old.buildInputs or [] ) ++ [ final.setuptools pkgs.openldap pkgs.cyrus_sasl ];
    });
    nginx-ldap-auth-service = prev.nginx-ldap-auth-service.overrideAttrs (old: {
      # Changes:
      # 1. Support unescaped service URL in query string.
      # 2. Change session ID to include username after login.
      # 3. Set samesite=strict for CSRF cookie.
      # 4. Remove CDN.
      patches = [
        ./nginx-ldap-auth-service-00.patch
        ./nginx-ldap-auth-service-01.patch
        ./nginx-ldap-auth-service-03.patch
      ];
    });
  };

  pythonSet =
  # Use base package set from pyproject.nix builders
  (pkgs.callPackage pyproject-nix.build.packages {
    inherit python;
  }).overrideScope
  (
    lib.composeManyExtensions [
      pyproject-build-systems.default
      overlay
      pyprojectOverrides
    ]
  );

  env = pythonSet.mkVirtualEnv "nginx-ldap-auth-service-env" workspace.deps.default;
}
