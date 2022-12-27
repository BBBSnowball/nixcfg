{ lib
, buildPythonApplication
, fetchFromGitHub
}:
let
in
  buildPythonApplication rec {
    pname = "cadquery-server";
    version = "0.4.1";

    src = fetchFromGitHub {
      owner = "roipoussiere";
      repo = pname;
      rev = version;
      #hash = "sha256-Oww54jPxkJzb1Y6Sv/vuKxRWbUhEoNjvrT8WjgD4lUI=";
    };

    buildInputs = [
    ];

    propagatedBuildInputs = [
      cadquery
    ];

    checkInputs = [
      pytest
    ];

    meta = with lib; {
      description = "A web server used to render 3d models from CadQuery code, and eventually build a static website as a showcase for your projects.";
      homepage = "https://github.com/roipoussiere/cadquery-server/";
      license = licenses.mit;
      maintainers = with maintainers; [ ];
    };
  }


#  [tool.poetry.dependencies]
#python = ">=3.8,<3.11"
#Flask = "^2.2.2"
#jupyter-cadquery = "^3.2.2"
#cadquery-massembly = "^0.9.0"
#matplotlib = "^3.5.3"
#minify-html = "^0.10.0"
#cadquery = {version = "2.2.0b0", optional = true, allow-prereleases = true}
#casadi = {version = "^3.5.6rc2", optional = true, allow-prereleases = true}
#CairoSVG = "^2.5.2"
#
#[tool.poetry.scripts]
#cq-server = "cq_server.cli:main"
#
#[tool.poetry.group.dev.dependencies]
#pylint = "^2.15.0"
#PyAutoGUI = "^0.9.53"
#paperclip = "^2.6.1"
#
#[build-system]
#requires = ["poetry-core>=1.0.0"]
#build-backend = "poetry.core.masonry.api"
#
#[tool.poetry.extras]
#cadquery = ["cadquery", "casadi"]
#{
#  https://github.com/roipoussiere/cadquery-server
#}
