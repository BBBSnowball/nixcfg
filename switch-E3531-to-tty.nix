self: super:
{
  usb-modeswitch-data = super.usb-modeswitch-data.overrideAttrs (x: {
    patches = (x.patches or []) ++ [ ./switch-E3531-to-tty.patch ];
  });
}
