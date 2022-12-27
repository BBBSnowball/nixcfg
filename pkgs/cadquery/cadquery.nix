{ lib
, buildPythonPackage
, toPythonModule
, pythonOlder
, pythonAtLeast
, fetchFromGitHub
, pyparsing
, opencascade
, stdenv
, python
, cmake
, swig
, smesh
, freetype
, libGL
, libGLU
, libX11
, six
, pytest
, makeFontsConf
, freefont_ttf
, Cocoa
, setuptools-scm
, ezdxf
, multimethod
, nlopt
, typish
, path
}:

let
  pythonocc-core-cadquery = toPythonModule (stdenv.mkDerivation {
    pname = "pythonocc-core-cadquery";
    version = "0.18.2";

    src = fetchFromGitHub {
      owner = "CadQuery";
      repo = "pythonocc-core";
      # no proper release to to use, this commit copied from the Anaconda receipe
      # -> not sure where to find this, let's use the master and hope for the best -> which is the same one as before
      rev = "701e924ae40701cbe6f9992bcbdc2ef22aa9b5ab";
      sha256 = "07zmiiw74dyj4v0ar5vqkvk30wzcpjjzbi04nsdk5mnlzslmyi6c";
    };

    nativeBuildInputs = [
      cmake
      swig
    ];

    buildInputs = [
      python
      opencascade
      smesh
      freetype
      libGL
      libGLU
      libX11
    ] ++ lib.optionals stdenv.isDarwin [ Cocoa ];

    propagatedBuildInputs = [
      six
    ];

    cmakeFlags = [
      "-Wno-dev"
      "-DPYTHONOCC_INSTALL_DIRECTORY=${placeholder "out"}/${python.sitePackages}/OCC"
      "-DSMESH_INCLUDE_PATH=${smesh}/include/smesh"
      "-DSMESH_LIB_PATH=${smesh}/lib"
      "-DPYTHONOCC_WRAP_SMESH=TRUE"
    ];

    preConfigure = ''
      export CXXFLAGS=-std=c++14
    '';
  });

in
  buildPythonPackage rec {
    name = "cadquery";
    pname = name;
    #version = "2.0";

    src = fetchFromGitHub {
      owner = "CadQuery";
      repo = pname;
      rev = "2.1";
      hash = "sha256-g60fC0DiMynOTT4vz3B9B7nbMWRdjfGuwIESUNdBZBM=";
      #rev = "4568e45b153af4f33d74e558f6e50dc803c14a84";
      #hash = "sha256-Oww54jPxkJzb1Y6Sv/vuKxRWbUhEoNjvrT8WjgD4lUI=";
    };

    buildInputs = [
      opencascade
    ];

    propagatedBuildInputs = [
      pyparsing
      pythonocc-core-cadquery
      setuptools-scm
      ezdxf
      multimethod
      nlopt
      typish
      path
    ];

    FONTCONFIG_FILE = makeFontsConf {
      fontDirectories = [ freefont_ttf ];
    };

    checkInputs = [
      pytest
    ];

    preConfigure = ''
      export SETUPTOOLS_SCM_PRETEND_VERSION=2.0
    '';

    #disabled = pythonOlder "3.6" || pythonAtLeast "3.8";

    meta = with lib; {
      description = "Parametric scripting language for creating and traversing CAD models";
      homepage = "https://github.com/CadQuery/cadquery";
      license = licenses.asl20;
      maintainers = with maintainers; [ costrouc marcus7070 ];
    };
  }
