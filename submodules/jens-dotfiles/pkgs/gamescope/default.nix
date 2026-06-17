{ stdenv, fetchFromGitHub, meson, pkgconfig, ninja, x11, xorg, libdrm, vulkan-headers, vulkan-loader, wayland, wayland-protocols, libxkbcommon, libcap, SDL2, wlroots, glslang, libliftoff, pixman, udev, libinput }:

stdenv.mkDerivation {
  pname = "gamescope";
  version = "git";

  src = fetchFromGitHub {
    owner = "Plagman";
    repo = "gamescope";
    rev = "85ba5c6fe92a4f4b441471676c84bc81aab9ce15";
    sha256 = "0kc4rd3gvj2f2zm73dfxa4y4s80yx5314aq51pd7rdw553aybcpq";
  };

  nativeBuildInputs = [ meson ninja pkgconfig vulkan-headers glslang wayland-protocols ];
  buildInputs = with xorg; [
    x11
    libXdamage
    libXcomposite
    libXrender
    libXext
    libXfixes
    libXxf86vm
    libXtst
    libXi
    libdrm
    vulkan-loader
    wayland
    libxkbcommon
    libcap
    SDL2
    wlroots
    libliftoff
    pixman
    udev
    libinput
  ];
}
