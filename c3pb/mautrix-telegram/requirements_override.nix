{ pkgs, python }:

self: super: {
  "pytest-mock" = super."pytest-mock".override (old: {
    propagatedBuildInputs = old.propagatedBuildInputs ++ [self."setuptools-scm"];
  });
  "python-magic" = super."python-magic".overrideAttrs (old: {
    postPatch = ''
      substituteInPlace magic.py --replace "ctypes.util.find_library('magic')" "'${pkgs.file}/lib/libmagic${pkgs.stdenv.hostPlatform.extensions.sharedLibrary}'"
    '';
  });
  "mautrix-appservice" = super."mautrix-appservice".overrideAttrs (old: {
    # future-fstrings package is added to propagatedBuildInputs but encoding isn't recognized.
    # We remove it as our Python should be new enough to not need it anyway.
    postPatch = ''
      find -type f -name "*.py" -exec sed '/^# -\*- coding: future_fstrings -\*-/ d' -i {} \+
    '';
  });
}
