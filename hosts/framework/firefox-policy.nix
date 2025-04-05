{ config, pkgs, ... }:
{
  programs.firefox = {
    enable = true;

    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DontCheckDefaultBrowser = true;
      DisablePocket = true;
      SearchBar = "separate";  # or "unified"

      # https://mozilla.github.io/policy-templates/#preferences
      Preferences = let
        lock = value: {
          Value = value;
          Status = "locked";
        };
      in {
        # first block copied from here (with some changes):
        # https://discourse.nixos.org/t/combining-best-of-system-firefox-and-home-manager-firefox-settings/37721

        # Privacy settings
        "extensions.pocket.enabled" = lock false;
        "browser.newtabpage.pinned" = lock "";
        "browser.topsites.contile.enabled" = lock false;
        "browser.newtabpage.activity-stream.showSponsored" = lock false;
        "browser.newtabpage.activity-stream.system.showSponsored" = lock false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = lock false;

        "browser.newtabpage.activity-stream.feeds.topsites" = lock false;
        "browser.newtabpage.enabled" = lock false;
        "browser.startup.homepage".Value = "about:blank";
        "browser.startup.page".Value = 3;
        "browser.safebrowsing.malware.enabled" = lock false;
        "browser.safebrowsing.phishing.enabled" = lock false;
        "browser.search.region".Value = "DE";
        "browser.tabs.inTitlebar".Value = 0;
        "browser.toolbars.bookmarks.visibility".Value = "never";
        "browser.translations.neverTranslateLanguages".Value = "de";
        "privacy.donottrackheader.enabled".Value = true;
        "privacy.fingerprintingProtection".Value = true;

        # dark theme: default seems to be fine (automatic)
      };

      # get IDs from about:support
      # (see https://mozilla.github.io/policy-templates/#extensionsettings)
      ExtensionSettings = let
        preinstall = id: extra: {
          ${id} = {
            #installation_mode = "force_installed";
            installation_mode = "normal_installed";
            # URL is suggested here: https://mozilla.github.io/policy-templates/#extensionsettings
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/${id}/latest.xpi";
          } // extra;
        };
      in
        # Tree Style Tab
        (preinstall "treestyletab@piro.sakura.ne.jp" {})
        # uBlock Origin
        // (preinstall "uBlock0@raymondhill.net" {})
        # Vimium
        // (preinstall "{d7742d87-e61d-4b78-b8a1-b469842139fa}" {})
        # Privacy Badger
        // (preinstall "jid1-MnnxcxisBPnSXQ@jetpack" {})
        # Decentraleyes
        // (preinstall "jid1-BoFifL9Vbdl2zQ@jetpack" {})
        # Greasemonkey
        #// (preinstall "{e4a8a97b-f2ed-450b-b12d-ee082ba24781}" {})
      ;
    };
  };
}
