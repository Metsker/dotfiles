{ config, lib, pkgs, ... }:

# Declarative browser web apps: each becomes a standalone chromium --app window.
# mango window-rules them by their chrome-<host>__-Default app-id (see rules.conf).
let
  iconDir = "${config.xdg.dataHome}/icons/webapps";

  # Web apps keyed by id (desktop entry name, icon filename).
  #   icon    = local path or theme name; set = no download.
  #   iconUrl = source to fetch; needed for self-hosted/auth-gated domains a
  #             favicon service can't reach (see https://dashboardicons.com).
  apps = {
    brain = {
      url = "https://brain.metsker.dev";
      name = "SilverBullet";
      iconUrl = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/silverbullet.png";
    };
    tldraw = {
      url = "https://tldraw.com";
      name = "tldraw";
    };
    youtube-music = {
      url = "https://music.youtube.com/";
      name = "YouTube Music";
    };
  };

  # Icon source per app: explicit iconUrl wins, else best-effort favicon.
  iconSrc = app:
    if app ? iconUrl then app.iconUrl
    else "https://www.google.com/s2/favicons?domain=${app.url}&sz=128";
in
{
  # uBlock Origin Lite (MV3) for the chromium webapp profile. package = null keeps
  # chromium off PATH (the webapp launcher provides it); Chromium auto-installs and
  # updates it from the Web Store. Classic uBlock Origin is MV2 - dead on Chromium 150.
  programs.chromium = {
    enable = true;
    package = null;
    extensions = [
      "ddkjiahejlhfcafbddmgiahcphecmpfh" # uBlock Origin Lite
    ];
  };

  xdg.desktopEntries = lib.mapAttrs (id: app: {
    name = app.name or id;
    exec = "webapp ${app.url}";
    icon = app.icon or "${iconDir}/${id}.png";
  }) apps;

  # Icons can't be fetched in pure Nix (fetchers need a pinned hash), so grab
  # them at activation time. Cached: only downloads a missing icon.
  # ponytail: to refresh after changing url/iconUrl, delete its .png and re-switch.
  home.activation.webappIcons = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    lib.concatStringsSep "\n" (lib.mapAttrsToList
      (id: app: lib.optionalString (!(app ? icon)) ''
        if [ ! -s "${iconDir}/${id}.png" ]; then
          run mkdir -p "${iconDir}"
          run ${lib.getExe pkgs.curl} -fsSL -o "${iconDir}/${id}.png" "${iconSrc app}" || true
          if [ ! -s "${iconDir}/${id}.png" ]; then
            rm -f "${iconDir}/${id}.png"
            warnEcho "webapps: no icon for '${id}' - set its iconUrl (try https://dashboardicons.com)"
          fi
        fi
      '')
      apps));
}
