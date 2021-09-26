{ pkgs ? import <nixpkgs> {}, fetchFromGitHub ? pkgs.fetchFromGitHub }:
let
in rec {
  packbits = p: p.buildPythonPackage rec {
    pname = "packbits";
    version = "0.6";
    src = p.fetchPypi {
      inherit pname version;
      sha256 = "sha256-vGs3C7NOBKyM+oNeBsBIQ4Cv/G1ZOtuACd1sD3v/8DQ=";
    };
  };
  brother-ql = p: p.buildPythonPackage rec {
    pname = "brother_ql";
    version = "0.9.4";
    src = p.fetchPypi {
      inherit pname version;
      sha256 = "sha256-H1xXoDnwEsnCBDl/RwAB9267dINCHr3phdDLPGFOhmA=";
    };
    propagatedBuildInputs = with p; [
      click
      future
      p.packbits
      pillow
      pyusb
      attrs
      matplotlib
    ];
    patches = [ ./brother_ql.patch ];
  };
  brother-ql-web = p: p.buildPythonPackage rec {
    pname = "brother_ql_web";
    version = "20200130";
    src = fetchFromGitHub {
      owner = "pklaus";
      repo = pname;
      rev = "9e20b6dc3f80589bffc0b1036aa3f7122ea4af89";
      sha256 = "sha256-yQPbrIkAhz0jc/j9HJ7VCB8n4a5Gi6TUIPBr7DhW/14=";
    };
    propagatedBuildInputs = with p; [ p.brother-ql bottle jinja2 ];

    setuppy = ''
      try:
        from setuptools import setup
      except ImportError:
        from distutils.core import setup
      
      setup(name='brother_ql_web',
        version = '${version}',
        packages = ['brother_ql_web', 'font_helpers'],
        entry_points = {
            'console_scripts': [
                'brother_ql_web = brother_ql_web:main',
            ],
        },
        include_package_data = False,
        zip_safe = True,
        platforms = 'any',
        install_requires = [
            "brother_ql",
            "jinja2",
            "bottle",
        ],
      )
    '';
    passAsFile = [ "setuppy" ];
    postPatch = ''
      cp $setuppyPath setup.py
      substituteInPlace brother_ql_web.py \
        --replace config.example.json $out/share/brother_ql_web/config.example.json \
        --replace "'./static'" "'$out/share/brother_ql_web/static'" \
        --replace "@view('" "@view('$out/share/brother_ql_web/views/"
      substituteInPlace views/labeldesigner.jinja2 \
        --replace '"base.jinja2"' "'$out/share/brother_ql_web/views/base.jinja2'"
      for x in brother_ql_web font_helpers ; do mkdir $x; mv $x.py $x/__init__.py ; done
    '';
    postInstall = ''
      mkdir -p $out/share/brother_ql_web/
      cp -r config.example.json static views $out/share/brother_ql_web/
    '';
  };
  pythonPackageOverrides = self: super: {
    packbits = packbits self;
    brother-ql = brother-ql self;
    brother-ql-web = brother-ql-web self;
  };
  overlay = (self: super: {
    python3 = super.python3.override { packageOverrides = pythonPackageOverrides; };
    python3Packages = self.python3.pkgs;
  });
  pkgs2 = overlay pkgs2 pkgs;
  #packbits = pkgs2.python3Packages.packbits;
  #brother-ql = pkgs2.python3Packages.brother-ql;
  #brother-ql-web = pkgs2.python3Packages.brother-ql-web;
  python = pkgs2.python3.withPackages (p: [ p.brother-ql p.brother-ql-web ]);

  shell = pkgs.mkShell {
    buildInputs = [ python ];
  };
}

