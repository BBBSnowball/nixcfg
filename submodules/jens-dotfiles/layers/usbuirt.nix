{ pkgs, lib, ... }:
with lib;

{
  services.lirc = {
    enable = true;
    options = ''
      [lircd]
      driver = uirt2_raw
      device = /dev/usbuirt
    '';
    configs = [''
      begin remote

      name  TeufelConceptF
      bits           32
      flags SPACE_ENC|CONST_LENGTH
      eps            30
      aeps          100

      header       8945  4313
      one           608  1546
      zero          608   454
      ptrail        602
      repeat       8904  2113
      gap          104541
      toggle_bit_mask 0x0
      frequency    38000

          begin codes
              KEY_POWER                0x04FB42BD 0xFFFFFFFF
              KEY_VOLUMEUP             0x04FBD02F 0xFFFFFFFF
              KEY_VOLUMEDOWN           0x04FB48B7 0xFFFFFFFF
              KEY_PC                   0x04FB629D 0xFFFFFFFF
              KEY_AUX                  0x04FB4AB5 0xFFFFFFFF
              KEY_DVD                  0x04FB5AA5 0xFFFFFFFF
              KEY_RESET                0x04FB6A95 0xFFFFFFFF
              KEY_MUTE                 0x04FBC837 0xFFFFFFFF
              KEY_21                   0x04FB40BF 0xFFFFFFFF
              KEY_51                   0x04FB50AF 0xFFFFFFFF
              KEY_SUB_UP               0x04FB6897 0xFFFFFFFF
              KEY_SUB_DOWN             0x04FB7887 0xFFFFFFFF
          end codes

    end remote
    ''];
  };

  services.udev.packages = singleton (pkgs.writeTextFile {
    name = "usbuirt-udev-rules";
    destination = "/etc/udev/rules.d/90-usbuirt.rules";
    text = ''
      SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="f850", GROUP="lirc", SYMLINK+="usbuirt"
    '';
  });
}
