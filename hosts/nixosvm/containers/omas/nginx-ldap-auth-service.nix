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
      patches = [
        ./nginx-ldap-auth/0001-support-unescaped-service-URL-in-query-string.patch
        ./nginx-ldap-auth/0002-change-session-ID-to-include-username-after-login.patch
        ./nginx-ldap-auth/0003-set-samesite-strict-for-CSRF-cookie.patch
        ./nginx-ldap-auth/0004-remove-CDN.patch
        ./nginx-ldap-auth/0005-add-auth-whoami.patch
        ./nginx-ldap-auth/0006-allow-Unix-socket-for-Redis-URL.patch
        ./nginx-ldap-auth/0007-include-domain-when-removing-cookie.patch
        ./nginx-ldap-auth/0008-add-options-for-Unix-socket-and-file-descriptor.patch
        #./nginx-ldap-auth/0006-debug.patch  # only for debugging
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
