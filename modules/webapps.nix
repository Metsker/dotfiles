{
  # Declarative browser web apps: each becomes a standalone helium --app window.
  # Helium keeps Chromium's chrome-<host>__<path>-Default app-id, which window rules match on.
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
        brain = {
          url = "https://notes.metsker.dev/brain";
          name = "Brain";
        };
        gamedev = {
          url = "https://notes.metsker.dev/gamedev";
          name = "Gamedev";
        };
        # youtube-music = {
        #   url = "https://music.youtube.com/";
        #   name = "YouTube Music";
        # };
        # soundcloud = {
        #   url = "https://soundcloud.com/";
        #   name = "SoundCloud";
        # };
      };

      # Icon source per app: explicit iconUrl wins, else best-effort favicon.
      iconSrc = app:
        if app ? iconUrl then app.iconUrl
        else "https://www.google.com/s2/favicons?domain=${app.url}&sz=128";
    in
    {
      # Launches URLs as standalone helium --app windows, in the main Helium profile.
      home.packages = [
        (pkgs.writeShellApplication {
          name = "webapp";
          runtimeInputs = [ pkgs.helium ];
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
      # To refresh after changing url/iconUrl, delete its .png and re-switch.
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
