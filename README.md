This repo contains most of my NixOS configs and Nix packages. Feel free to browse around and take whatever is useful.

* My main focus is on microcontrollers (and FPGAs), e.g. toolchains for ESP32 and GD32VF103.
* I'm interested in non-x86 architectures. I have a RockPro64 and I will buy a RISC-V boards
  as soon as they are available at an ok-ish price point.
* This repository is a Nix flake. See `bootstrap` if you want to build it with an old Nix.
  You can always use individual files without using flakes, of course. I suggest that you
  enable flakes on your system because they are extremely useful - lines 4 to 8 in
  `modules/enable-flakes.nix` is all that is needed.
* WPA Enterprise with hostapd plus a small script for managing client certificates
* Firewall configuration with Shorewall.
* See `modules` for all the small but useful stuff.

Hardware (with NixOS):

* My laptop and servers (x86_64)
* GPD Pocket
* RockPro64

Hardware (without NixOS):

* GD32VF103 (RISC-V)
* ESP32
* (nRF52) (PineTime)
* 8051 (PineBook Pro keyboard, PinePhone keyboard) - coming soon-ish

You can use the code in this repository under the terms of the MIT license. However, I'm using
several other flakes and repositories, which have their own licenses. Please respect the licenses
of any code you are using. If you want to add code, you must make it available under the MIT license.
Please indicate this in the pull request, e.g. by adding a Signed-Off line to the PR or commits.
