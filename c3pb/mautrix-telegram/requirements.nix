# generated using pypi2nix tool (version: 2.0.4)
# See more at: https://github.com/nix-community/pypi2nix
#
# COMMAND:
#   pypi2nix -r requirements.txt
#

{ pkgs ? import <nixpkgs> {},
  overrides ? ({ pkgs, python }: self: super: {})
}:

let

  inherit (pkgs) makeWrapper;
  inherit (pkgs.stdenv.lib) fix' extends inNixShell;

  pythonPackages =
  import "${toString pkgs.path}/pkgs/top-level/python-packages.nix" {
    inherit pkgs;
    inherit (pkgs) stdenv;
    python = pkgs.python3;
  };

  commonBuildInputs = [];
  commonDoCheck = false;

  withPackages = pkgs':
    let
      pkgs = builtins.removeAttrs pkgs' ["__unfix__"];
      interpreterWithPackages = selectPkgsFn: pythonPackages.buildPythonPackage {
        name = "python3-interpreter";
        buildInputs = [ makeWrapper ] ++ (selectPkgsFn pkgs);
        buildCommand = ''
          mkdir -p $out/bin
          ln -s ${pythonPackages.python.interpreter} \
              $out/bin/${pythonPackages.python.executable}
          for dep in ${builtins.concatStringsSep " "
              (selectPkgsFn pkgs)}; do
            if [ -d "$dep/bin" ]; then
              for prog in "$dep/bin/"*; do
                if [ -x "$prog" ] && [ -f "$prog" ]; then
                  ln -s $prog $out/bin/`basename $prog`
                fi
              done
            fi
          done
          for prog in "$out/bin/"*; do
            wrapProgram "$prog" --prefix PYTHONPATH : "$PYTHONPATH"
          done
          pushd $out/bin
          ln -s ${pythonPackages.python.executable} python
          ln -s ${pythonPackages.python.executable} \
              python3
          popd
        '';
        passthru.interpreter = pythonPackages.python;
      };

      interpreter = interpreterWithPackages builtins.attrValues;
    in {
      __old = pythonPackages;
      inherit interpreter;
      inherit interpreterWithPackages;
      mkDerivation = args: pythonPackages.buildPythonPackage (args // {
        nativeBuildInputs = (args.nativeBuildInputs or []) ++ args.buildInputs;
      });
      packages = pkgs;
      overrideDerivation = drv: f:
        pythonPackages.buildPythonPackage (
          drv.drvAttrs // f drv.drvAttrs // { meta = drv.meta; }
        );
      withPackages = pkgs'':
        withPackages (pkgs // pkgs'');
    };

  python = withPackages {};

  generated = self: {
    "aiohttp" = python.mkDerivation {
      name = "aiohttp-3.6.2";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/00/94/f9fa18e8d7124d7850a5715a0b9c0584f7b9375d331d35e157cee50f27cc/aiohttp-3.6.2.tar.gz";
        sha256 = "259ab809ff0727d0e834ac5e8a283dc5e3e0ecc30c4d80b3cd17a4139ce1f326";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [
        self."async-timeout"
        self."attrs"
        self."chardet"
        self."multidict"
        self."yarl"
      ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://github.com/aio-libs/aiohttp";
        license = licenses.asl20;
        description = "Async http client/server framework (asyncio)";
      };
    };

    "alembic" = python.mkDerivation {
      name = "alembic-1.4.2";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/60/1e/cabc75a189de0fbb2841d0975243e59bde8b7822bacbb95008ac6fe9ad47/alembic-1.4.2.tar.gz";
        sha256 = "035ab00497217628bf5d0be82d664d8713ab13d37b630084da8e1f98facf4dbf";
};
      doCheck = commonDoCheck;
      format = "pyproject";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [
        self."mako"
        self."python-dateutil"
        self."python-editor"
        self."sqlalchemy"
      ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://alembic.sqlalchemy.org";
        license = licenses.mit;
        description = "A database migration tool for SQLAlchemy.";
      };
    };

    "async-timeout" = python.mkDerivation {
      name = "async-timeout-3.0.1";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/a1/78/aae1545aba6e87e23ecab8d212b58bb70e72164b67eb090b81bb17ad38e3/async-timeout-3.0.1.tar.gz";
        sha256 = "0c3c816a028d47f659d6ff5c745cb2acf1f966da1fe5c19c77a70282b25f4c5f";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [ ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://github.com/aio-libs/async_timeout/";
        license = licenses.asl20;
        description = "Timeout context manager for asyncio programs";
      };
    };

    "attrs" = python.mkDerivation {
      name = "attrs-19.3.0";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/98/c3/2c227e66b5e896e15ccdae2e00bbc69aa46e9a8ce8869cc5fa96310bf612/attrs-19.3.0.tar.gz";
        sha256 = "f7b7ce16570fe9965acd6d30101a28f62fb4a7f9e926b3bbc9b61f8b04247e72";
};
      doCheck = commonDoCheck;
      format = "pyproject";
      buildInputs = commonBuildInputs ++ [
        self."setuptools"
        self."wheel"
      ];
      propagatedBuildInputs = [ ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://www.attrs.org/";
        license = licenses.mit;
        description = "Classes Without Boilerplate";
      };
    };

    "chardet" = python.mkDerivation {
      name = "chardet-3.0.4";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/fc/bb/a5768c230f9ddb03acc9ef3f0d4a3cf93462473795d18e9535498c8f929d/chardet-3.0.4.tar.gz";
        sha256 = "84ab92ed1c4d4f16916e05906b6b75a6c0fb5db821cc65e70cbd64a3e2a5eaae";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [ ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://github.com/chardet/chardet";
        license = licenses.lgpl2;
        description = "Universal encoding detector for Python 2 and 3";
      };
    };

    "commonmark" = python.mkDerivation {
      name = "commonmark-0.9.1";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/60/48/a60f593447e8f0894ebb7f6e6c1f25dafc5e89c5879fdc9360ae93ff83f0/commonmark-0.9.1.tar.gz";
        sha256 = "452f9dc859be7f06631ddcb328b6919c67984aca654e5fefb3914d54691aed60";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [ ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://github.com/rtfd/commonmark.py";
        license = licenses.bsdOriginal;
        description = "Python parser for the CommonMark Markdown spec";
      };
    };

    "future-fstrings" = python.mkDerivation {
      name = "future-fstrings-1.2.0";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/5d/e2/3874574cce18a2e3608abfe5b4b5b3c9765653c464f5da18df8971cf501d/future_fstrings-1.2.0.tar.gz";
        sha256 = "6cf41cbe97c398ab5a81168ce0dbb8ad95862d3caf23c21e4430627b90844089";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [ ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://github.com/asottile/future-fstrings";
        license = licenses.mit;
        description = "A backport of fstrings to python<3.6";
      };
    };

    "idna" = python.mkDerivation {
      name = "idna-2.9";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/cb/19/57503b5de719ee45e83472f339f617b0c01ad75cba44aba1e4c97c2b0abd/idna-2.9.tar.gz";
        sha256 = "7588d1c14ae4c77d74036e8c22ff447b26d0fde8f007354fd48a7814db15b7cb";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [ ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://github.com/kjd/idna";
        license = licenses.bsdOriginal;
        description = "Internationalized Domain Names in Applications (IDNA)";
      };
    };

    "mako" = python.mkDerivation {
      name = "mako-1.1.3";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/72/89/402d2b4589e120ca76a6aed8fee906a0f5ae204b50e455edd36eda6e778d/Mako-1.1.3.tar.gz";
        sha256 = "8195c8c1400ceb53496064314c6736719c6f25e7479cd24c77be3d9361cddc27";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [
        self."markupsafe"
      ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://www.makotemplates.org/";
        license = licenses.mit;
        description = "A super-fast templating language that borrows the  best ideas from the existing templating languages.";
      };
    };

    "markupsafe" = python.mkDerivation {
      name = "markupsafe-1.1.1";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/b9/2e/64db92e53b86efccfaea71321f597fa2e1b2bd3853d8ce658568f7a13094/MarkupSafe-1.1.1.tar.gz";
        sha256 = "29872e92839765e546828bb7754a68c418d927cd064fd4708fab9fe9c8bb116b";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [ ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://palletsprojects.com/p/markupsafe/";
        license = licenses.bsdOriginal;
        description = "Safely add untrusted strings to HTML/XML markup.";
      };
    };

    "mautrix-appservice" = python.mkDerivation {
      name = "mautrix-appservice-0.3.11";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/ba/31/594f902a147fb60eb0f9ab6cd17122c4839d6d7ac7b1af5030a02be6108e/mautrix-appservice-0.3.11.tar.gz";
        sha256 = "60192920cff75afdd096eea3a43276e33ec15f4f00bd04d2d1dda616c84f22a5";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [
        self."aiohttp"
        self."future-fstrings"
      ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://github.com/tulir/mautrix-appservice-python";
        license = licenses.mit;
        description = "A Python 3 asyncio-based Matrix application service framework.";
      };
    };

    "multidict" = python.mkDerivation {
      name = "multidict-4.7.6";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/65/d4/fabdcc5ee4451c8a8e177e27ddfd131a53a82ecc5a3b68468b7e9f8d70b4/multidict-4.7.6.tar.gz";
        sha256 = "fbb77a75e529021e7c4a8d4e823d88ef4d23674a202be4f5addffc72cbb91430";
};
      doCheck = commonDoCheck;
      format = "pyproject";
      buildInputs = commonBuildInputs ++ [
        self."pip"
        self."setuptools"
        self."wheel"
      ];
      propagatedBuildInputs = [ ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://github.com/aio-libs/multidict";
        license = licenses.asl20;
        description = "multidict implementation";
      };
    };

    "pip" = python.mkDerivation {
      name = "pip-20.1.1";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/08/25/f204a6138dade2f6757b4ae99bc3994aac28a5602c97ddb2a35e0e22fbc4/pip-20.1.1.tar.gz";
        sha256 = "27f8dc29387dd83249e06e681ce087e6061826582198a425085e0bf4c1cf3a55";
};
      doCheck = commonDoCheck;
      format = "pyproject";
      buildInputs = commonBuildInputs ++ [
        self."setuptools"
        self."wheel"
      ];
      propagatedBuildInputs = [ ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://pip.pypa.io/";
        license = licenses.mit;
        description = "The PyPA recommended tool for installing Python packages.";
      };
    };

    "pyaes" = python.mkDerivation {
      name = "pyaes-1.6.1";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/44/66/2c17bae31c906613795711fc78045c285048168919ace2220daa372c7d72/pyaes-1.6.1.tar.gz";
        sha256 = "02c1b1405c38d3c370b085fb952dd8bea3fadcee6411ad99f312cc129c536d8f";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [ ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://github.com/ricmoo/pyaes";
        license = licenses.mit;
        description = "Pure-Python Implementation of the AES block-cipher and common modes of operation";
      };
    };

    "pyasn1" = python.mkDerivation {
      name = "pyasn1-0.4.8";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/a4/db/fffec68299e6d7bad3d504147f9094830b704527a7fc098b721d38cc7fa7/pyasn1-0.4.8.tar.gz";
        sha256 = "aef77c9fb94a3ac588e87841208bdec464471d9871bd5050a287cc9a475cd0ba";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [ ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://github.com/etingof/pyasn1";
        license = licenses.bsdOriginal;
        description = "ASN.1 types and codecs";
      };
    };

    "python-dateutil" = python.mkDerivation {
      name = "python-dateutil-2.8.1";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/be/ed/5bbc91f03fa4c839c4c7360375da77f9659af5f7086b7a7bdda65771c8e0/python-dateutil-2.8.1.tar.gz";
        sha256 = "73ebfe9dbf22e832286dafa60473e4cd239f8592f699aa5adaf10050e6e1823c";
};
      doCheck = commonDoCheck;
      format = "pyproject";
      buildInputs = commonBuildInputs ++ [
        self."setuptools"
        self."setuptools-scm"
        self."wheel"
      ];
      propagatedBuildInputs = [
        self."six"
      ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://dateutil.readthedocs.io";
        license = licenses.bsdOriginal;
        description = "Extensions to the standard Python datetime module";
      };
    };

    "python-editor" = python.mkDerivation {
      name = "python-editor-1.0.4";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/0a/85/78f4a216d28343a67b7397c99825cff336330893f00601443f7c7b2f2234/python-editor-1.0.4.tar.gz";
        sha256 = "51fda6bcc5ddbbb7063b2af7509e43bd84bfc32a4ff71349ec7847713882327b";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [ ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://github.com/fmoo/python-editor";
        license = licenses.asl20;
        description = "Programmatically open an editor, capture the result.";
      };
    };

    "python-magic" = python.mkDerivation {
      name = "python-magic-0.4.18";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/e3/85/1aff76b966622868a73717abd8b501a3c91890e23a65e5f574ff6df1970f/python-magic-0.4.18.tar.gz";
        sha256 = "b757db2a5289ea3f1ced9e60f072965243ea43a2221430048fd8cacab17be0ce";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [ ];
      meta = with pkgs.stdenv.lib; {
        homepage = "http://github.com/ahupp/python-magic";
        license = licenses.mit;
        description = "File type identification using libmagic";
      };
    };

    "rsa" = python.mkDerivation {
      name = "rsa-4.6";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/a2/d5/04b8a9719149583fec76efdff2e7a81c6e3cc34909ee818d3fbf115edc2e/rsa-4.6.tar.gz";
        sha256 = "109ea5a66744dd859bf16fe904b8d8b627adafb9408753161e766a92e7d681fa";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [
        self."pyasn1"
      ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://stuvel.eu/rsa";
        license = licenses.asl20;
        description = "Pure-Python RSA implementation";
      };
    };

    "ruamel-yaml" = python.mkDerivation {
      name = "ruamel-yaml-0.16.10";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/16/8b/54a26c1031595e5edd0e616028b922d78d8ffba8bc775f0a4faeada846cc/ruamel.yaml-0.16.10.tar.gz";
        sha256 = "099c644a778bf72ffa00524f78dd0b6476bca94a1da344130f4bf3381ce5b954";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [
        self."ruamel-yaml-clib"
      ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://sourceforge.net/p/ruamel-yaml/code/ci/default/tree";
        license = licenses.mit;
        description = "ruamel.yaml is a YAML parser/emitter that supports roundtrip preservation of comments, seq/map flow style, and map key order";
      };
    };

    "ruamel-yaml-clib" = python.mkDerivation {
      name = "ruamel-yaml-clib-0.2.0";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/92/28/612085de3fae9f82d62d80255d9f4cf05b1b341db1e180adcf28c1bf748d/ruamel.yaml.clib-0.2.0.tar.gz";
        sha256 = "b66832ea8077d9b3f6e311c4a53d06273db5dc2db6e8a908550f3c14d67e718c";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [ ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://bitbucket.org/ruamel/yaml.clib";
        license = licenses.mit;
        description = "C version of reader, parser and emitter for ruamel.yaml derived from libyaml";
      };
    };

    "setuptools" = python.mkDerivation {
      name = "setuptools-47.1.1";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/25/bf/a37e89d3148221fedd4def62bb68749041d79f3840d58a7943f81a6f6c6e/setuptools-47.1.1.zip";
        sha256 = "145fa62b9d7bb544fce16e9b5a9bf4ab2032d2f758b7cd674af09a92736aff74";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [ ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://github.com/pypa/setuptools";
        license = licenses.mit;
        description = "Easily download, build, install, upgrade, and uninstall Python packages";
      };
    };

    "setuptools-scm" = python.mkDerivation {
      name = "setuptools-scm-4.1.2";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/cd/66/fa77e809b7cb1c2e14b48c7fc8a8cd657a27f4f9abb848df0c967b6e4e11/setuptools_scm-4.1.2.tar.gz";
        sha256 = "a8994582e716ec690f33fec70cca0f85bd23ec974e3f783233e4879090a7faa8";
};
      doCheck = commonDoCheck;
      format = "pyproject";
      buildInputs = commonBuildInputs ++ [
        self."setuptools"
        self."wheel"
      ];
      propagatedBuildInputs = [
        self."setuptools"
      ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://github.com/pypa/setuptools_scm/";
        license = licenses.mit;
        description = "the blessed package to manage your versions by scm tags";
      };
    };

    "six" = python.mkDerivation {
      name = "six-1.15.0";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/6b/34/415834bfdafca3c5f451532e8a8d9ba89a21c9743a0c59fbd0205c7f9426/six-1.15.0.tar.gz";
        sha256 = "30639c035cdb23534cd4aa2dd52c3bf48f06e5f4a941509c8bafd8ce11080259";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [ ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://github.com/benjaminp/six";
        license = licenses.mit;
        description = "Python 2 and 3 compatibility utilities";
      };
    };

    "sqlalchemy" = python.mkDerivation {
      name = "sqlalchemy-1.3.17";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/84/f4/5a61726869da51f37f643ea92bfa440e32eb182bdc1a1c7cfc9504930a95/SQLAlchemy-1.3.17.tar.gz";
        sha256 = "156a27548ba4e1fed944ff9fcdc150633e61d350d673ae7baaf6c25c04ac1f71";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [ ];
      meta = with pkgs.stdenv.lib; {
        homepage = "http://www.sqlalchemy.org";
        license = licenses.mit;
        description = "Database Abstraction Library";
      };
    };

    "telethon" = python.mkDerivation {
      name = "telethon-1.14.0";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/84/96/1af41e773e0e2e6f123fc71bd0a2080048f4f34fc1dbd080b517ff8955a5/Telethon-1.14.0.tar.gz";
        sha256 = "d8bb37f80c4a8befa92d0525f00a578a74064645e48d7aa0cc4731f3d813e1b9";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [
        self."pyaes"
        self."rsa"
      ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://github.com/LonamiWebs/Telethon";
        license = licenses.mit;
        description = "Full-featured Telegram client library for Python 3";
      };
    };

    "telethon-session-sqlalchemy" = python.mkDerivation {
      name = "telethon-session-sqlalchemy-0.2.15";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/5a/cf/e558fe7af77ba06251916e1c5450e156e96709e47df4c5c782a2ac077ae7/telethon-session-sqlalchemy-0.2.15.tar.gz";
        sha256 = "2ba603d95d5be6ddecd8ecaeaffba00b75b49dd80eb77f6228dd7b793ca67fd2";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [
        self."sqlalchemy"
      ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://github.com/tulir/telethon-session-sqlalchemy";
        license = licenses.mit;
        description = "SQLAlchemy backend for Telethon session storage";
      };
    };

    "wheel" = python.mkDerivation {
      name = "wheel-0.34.2";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/75/28/521c6dc7fef23a68368efefdcd682f5b3d1d58c2b90b06dc1d0b805b51ae/wheel-0.34.2.tar.gz";
        sha256 = "8788e9155fe14f54164c1b9eb0a319d98ef02c160725587ad60f14ddc57b6f96";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [
        self."setuptools"
      ];
      propagatedBuildInputs = [ ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://github.com/pypa/wheel";
        license = licenses.mit;
        description = "A built-package format for Python";
      };
    };

    "yarl" = python.mkDerivation {
      name = "yarl-1.4.2";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/d6/67/6e2507586eb1cfa6d55540845b0cd05b4b77c414f6bca8b00b45483b976e/yarl-1.4.2.tar.gz";
        sha256 = "58cd9c469eced558cd81aa3f484b2924e8897049e06889e8ff2510435b7ef74b";
};
      doCheck = commonDoCheck;
      format = "setuptools";
      buildInputs = commonBuildInputs ++ [ ];
      propagatedBuildInputs = [
        self."idna"
        self."multidict"
      ];
      meta = with pkgs.stdenv.lib; {
        homepage = "https://github.com/aio-libs/yarl/";
        license = licenses.asl20;
        description = "Yet another URL library";
      };
    };
  };
  localOverridesFile = ./requirements_override.nix;
  localOverrides = import localOverridesFile { inherit pkgs python; };
  commonOverrides = [
        (let src = pkgs.fetchFromGitHub { owner = "nix-community"; repo = "pypi2nix-overrides"; rev = "90e891e83ffd9e55917c48d24624454620d112f0"; sha256 = "0cl1r3sxibgn1ks9xyf5n3rdawq4hlcw4n6xfhg3s1kknz54jp9y"; } ; in import "${src}/overrides.nix" { inherit pkgs python; })
  ];
  paramOverrides = [
    (overrides { inherit pkgs python; })
  ];
  allOverrides =
    (if (builtins.pathExists localOverridesFile)
     then [localOverrides] else [] ) ++ commonOverrides ++ paramOverrides;

in python.withPackages
   (fix' (pkgs.lib.fold
            extends
            generated
            allOverrides
         )
   )