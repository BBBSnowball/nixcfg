self: super:

rec {
  neovim-queezle = import ./neovim { pkgs = self; };
  simpleandsoft = import ./simpleandsoft { pkgs = self; };
  netevent = self.callPackage ./netevent {};
  g810-led = self.callPackage ./g810-led {};

  libliftoff = self.callPackage ./libliftoff {};
  gamescope = self.callPackage ./gamescope {};

  pragmatapro = self.callPackage ./pragmatapro {};

  mpv-queezle = self.mpv-with-scripts.override {
    scripts = [ self.mpvScripts.mpris ];
  };

  fuzzel = super.fuzzel.overrideAttrs (old: old // {
    src = self.fetchFromGitea {
      domain = "codeberg.org";
      owner = "dnkl";
      repo = "fuzzel";
      rev = "0014c0b2e33d4c967c26f2ccc34013a2a3cbb7bc";
      sha256 = "sha256-fYPXKnJFZVh4vPq7g0qLBEPl/LPUC3By7bVmN9mwsJg=";
    };
  });

  haskell = super.haskell // {
    packageOverrides = hself: hsuper: super.haskell.packageOverrides hself hsuper // {
      #net-mqtt = self.haskell.lib.doJailbreak hsuper.net-mqtt;
      #net-mqtt = self.haskell.lib.unmarkBroken hsuper.net-mqtt;
      qbar = hself.callPackage ./qbar {};
    };
  };

  mumble-git = (self.mumble.overrideAttrs (attrs: {
    src = self.fetchFromGitHub {
      owner = "mumble-voip";
      repo = "mumble";
      rev = "f8ee53688353c8f5e1650504a961ee582ac16668";
      sha256 = "1ifax91w5d0311sx8nkflfih61ccn0vcghyl1j6r8qn96zvz5dzq";
      fetchSubmodules = true;
    };
  }));

  qbar = self.haskellPackages.qbar;
}
