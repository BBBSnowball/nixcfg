{ fetchFromGitHub, python3Packages }:
python3Packages.buildPythonPackage rec {
  pname = "apio";
  version = "6.0.0";

  src = fetchFromGitHub {
    owner = "FPGAwars";
    repo = "apio";
    rev = "v6.0.0";
    sha256 = "sha256-8x3LErViXQ6iwegFkEWrGl9JcEZpRdNjUo1uVu7clu8=";
  };

  buildInputs = with python3Packages; [ pytest ];

  propagatedBuildInputs = with python3Packages; [
    click semantic-version requests pyjwt colorama pyserial newWheel
  ];

  PYTHONPATH = "${newWheel}/lib/python3.8/site-packages";

  passthru.wheel = newWheel;

  patchPhase = ''
    sed -i 's/click>=5,<7/click>=5,<8/' setup.py
  '';
}
