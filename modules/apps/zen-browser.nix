{ inputs, ... }:

{
  flake.modules.homeManager.metsker = {
    imports = [ inputs.zen-browser.homeModules.default ];

    programs.zen-browser = {
      enable = true;
      profiles.default.settings = {
        "toolkit.legacyUserProfileCustomizations.stylesheets" = false;
        "zen.theme.content-element-separation" = 0;
        "zen.view.experimental-no-window-controls" = true;
        "zen.widget.linux.transparency" = false;
        "browser.tabs.allow_transparent_browser" = true;
        "browser.tabs.hoverPreview.enabled" = true;
        # Default 2 (auto) only picks the portal when sandboxed; 1 forces it, so uploads get the GTK picker.
        "widget.use-xdg-desktop-portal.file-picker" = 1;
      };
    };

    xdg.mimeApps.defaultApplications = {
      "text/html" = "zen-beta.desktop";
      "application/xhtml+xml" = "zen-beta.desktop";
      "x-scheme-handler/http" = "zen-beta.desktop";
      "x-scheme-handler/https" = "zen-beta.desktop";
      "x-scheme-handler/about" = "zen-beta.desktop";
      "x-scheme-handler/unknown" = "zen-beta.desktop";
    };
  };
}
