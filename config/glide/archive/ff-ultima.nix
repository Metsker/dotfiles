# FF Ultima on glide, tried on 2026-11-16 - not a module (config/ is never imported).
# To restore: add the flake input below, put these bindings in apps.nix's let and the attributes
# in its home module (with lib in its arguments), and paste ff-ultima-prefs.js into about:config
# or user.js for the settings it had.
#
#   ff-ultima = {
#     url = "github:soulhotel/ff-ultima/73129fafa3649c9019a968044edc1de66b031136";
#     flake = false;
#   };
{ lib, pkgs, inputs, ... }:
let
  # FF Ultima ships fx-autoconfig under chrome/userchromejs, so the loader looks there instead of chrome/utils.
  fxLoader = builtins.readFile "${inputs.fx-autoconfig}/program/config.js";
  ultimaLoader = assert lib.hasInfix "cmanifest.append('utils');" fxLoader;
    pkgs.writeText "ff-ultima-loader.js" (builtins.replaceStrings
      [ "cmanifest.append('utils');" ]
      [ "cmanifest.append('userchromejs'); cmanifest.append('utils');" ]
      fxLoader + "\n");

  # The settings ucc.json switches on, as default prefs: about:config and the companion add-on still override them.
  uccOptions = (lib.importJSON "${inputs.ff-ultima}/ucc.json").options;
  leaves = lib.concatMap (o: if o ? options then leaves o.options else [ o ]);
  ultimaOn = lib.unique (map (o: o.pref) (lib.filter
    (o: (o.on or false) && (lib.hasPrefix "ultima." o.pref || lib.hasPrefix "ffu." o.pref))
    (leaves uccOptions)));
  ultimaDefaults = pkgs.writeText "ff-ultima-defaults.js" ''
    ${lib.concatMapStrings (p: "defaultPref(\"${p}\", true);\n") ultimaOn}
    defaultPref("userChromeJS.gBrowser_hack.enabled", true);
    // Skips ffu.prefs.uc.js, whose one-time setup also turns off add-on signing and the remote debugging prompt.
    defaultPref("ffu.enable-recommended-prefs", "handled");
  '';
in
{
  programs.glide-browser = {
    enable = true;
    package = pkgs.wrapFirefox inputs.glide.packages.${pkgs.stdenv.hostPlatform.system}.glide-browser-bin-unwrapped {
      pname = "glide-browser";
      # fx-autoconfig's loader runs as mozilla.cfg, which needs privileged JS.
      extraAutoConfig = ''pref("general.config.sandbox_enabled", false);'';
      extraPrefsFiles = [ ultimaLoader ultimaDefaults ];
    };
    profiles.default.settings = {
      "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
      # FF Ultima's icons take their color from the theme through context-fill.
      "svg.context-properties.content.enabled" = true;
    };
  };

  home.file.".config/glide/glide/default/chrome" = {
    source = inputs.ff-ultima;
    # The startup cache keeps serving the previous scripts after an update.
    onChange = ''rm -rf "$HOME/.cache/glide/glide/default/startupCache"'';
  };
}
