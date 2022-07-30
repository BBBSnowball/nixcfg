
/nix/store/imnkgbq565lbwnlw4bn72w7j7dgpamn4-cups-progs/lib/cups/filter/pdftopdf ...
/nix/store/imnkgbq565lbwnlw4bn72w7j7dgpamn4-cups-progs/lib/cups/filter/pdftops ...
/nix/store/ywmaw1b8yhhvcp24rlda9d1zq9qqdcki-cups-progs/lib/cups/filter/brother_lpdwrapper_mfc9142cdn 24 user Netzwerk.odt 1 "InputSlot=Default PageSize=Letter job-uuid=urn:uuid:dea205e0-0923-3634-5195-ac18b6f9de8a job-originating-host-name=localhost date-time-at-creation= date-time-at-processing= time-at-creation=1658517458 time-at-processing=1658517458 document-name-supplied=Z2mCoP"  < /tmp/br_input.C7nRsj  >/tmp/y
cat >/tmp/job.ipp <<EOF
{
 OPERATION Print-Job
 GROUP operation-attributes-tag
  ATTR charset attributes-charset utf-8
  ATTR language attributes-natural-language en
  ATTR uri printer-uri $uri
 FILE /tmp/y
}
EOF
ipptool -tv -f abc.pdf ipp://192.168.178.21:631/ipp/print /tmp/job.ipp


# I finally got it to work with cups: We have to use the IP because the mDNS name doesn't work (also doesn't work in this script) but that's what the config dialog uses by default.
