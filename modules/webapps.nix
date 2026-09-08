{
  # Declarative browser web apps: each becomes a standalone chromium --app window.
  # mango window-rules them by their chrome-<host>__-Default app-id (see rules.conf).
  flake.modules.homeManager.metsker = { config, lib, pkgs, ... }:
    let
      iconDir = "${config.xdg.dataHome}/icons/webapps";

      # Web apps keyed by id (desktop entry name, icon filename).
      #   icon    = local path or theme name; set = no download.
      #   iconUrl = source to fetch; needed for self-hosted/auth-gated domains a
      #             favicon service can't reach (see https://dashboardicons.com).
      apps = {
        tldraw = {
          url = "https://tldraw.com/";
          name = "tldraw";
        };
        youtube-music = {
          url = "https://music.youtube.com/";
          name = "YouTube Music";
        };
        soundcloud = {
          url = "https://soundcloud.com/";
          name = "SoundCloud";
        };
      };

      # Icon source per app: explicit iconUrl wins, else best-effort favicon.
      iconSrc = app:
        if app ? iconUrl then app.iconUrl
        else "https://www.google.com/s2/favicons?domain=${app.url}&sz=128";
    in
    {
      # uBlock Origin Lite (MV3) for the chromium profile the webapps share; Chromium
      # auto-installs and updates it from the Web Store. Classic uBlock Origin is MV2 -
      # dead on Chromium 150.
      programs.chromium = {
        enable = true;
        package = pkgs.chromium;
        extensions = [
          "ddkjiahejlhfcafbddmgiahcphecmpfh" # uBlock Origin Lite
        ];
      };

      # Launches URLs as standalone chromium --app windows.
      home.packages = [
        (pkgs.writeShellApplication {
          name = "webapp";
          runtimeInputs = [ pkgs.chromium ];
          text = builtins.readFile ../scripts/webapp.sh;
        })
      ];

      xdg.desktopEntries = lib.mapAttrs
        (id: app: {
          name = app.name or id;
          exec = "webapp ${app.url}";
          icon = app.icon or "${iconDir}/${id}.png";
        })
        apps;

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
          apps)
      );
    };
}
