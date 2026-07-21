{ config, lib, pkgs, ... }:

# Declarative browser web apps: each becomes a standalone --app window with a
# stable app-id (--class / StartupWMClass) so mango can window-rule it.
let
  cfg = config.programs.webapps;
  iconDir = "${config.xdg.dataHome}/icons/webapps";

  # Icon source per app: explicit iconUrl wins, else best-effort favicon.
  # Third-party favicon services can't reach self-hosted/auth-gated domains,
  # so those apps must set iconUrl (see https://dashboardicons.com).
  iconSrc = app:
    if app.iconUrl != null then app.iconUrl
    else "https://www.google.com/s2/favicons?domain=${app.url}&sz=128";
in
{
  options.programs.webapps = {
    enable = lib.mkEnableOption "declarative browser web apps";

    browser = lib.mkOption {
      type = lib.types.str;
      default = lib.getExe pkgs.chromium;
      description = "Chromium-based browser binary used for --app windows.";
    };

    apps = lib.mkOption {
      default = { };
      description = "Web apps keyed by app-id (used for --class and window rules).";
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          url = lib.mkOption { type = lib.types.str; };
          name = lib.mkOption { type = lib.types.str; default = name; };
          icon = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Local icon path or theme name. Set = no download.";
          };
          iconUrl = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Icon URL to download. Needed for self-hosted apps.";
          };
        };
      }));
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.desktopEntries = lib.mapAttrs (id: app: {
      name = app.name;
      exec = "${cfg.browser} --app=${app.url} --class=${id} --ozone-platform-hint=auto";
      icon = if app.icon != null then app.icon else "${iconDir}/${id}.png";
      settings.StartupWMClass = id;
    }) cfg.apps;

    # Icons can't be fetched in pure Nix (fetchers need a pinned hash), so grab
    # them at activation time. Cached: only downloads a missing icon.
    # ponytail: to refresh after changing url/iconUrl, delete its .png and re-switch.
    home.activation.webappIcons = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      lib.concatStringsSep "\n" (lib.mapAttrsToList
        (id: app: lib.optionalString (app.icon == null) ''
          if [ ! -s "${iconDir}/${id}.png" ]; then
            run mkdir -p "${iconDir}"
            run ${lib.getExe pkgs.curl} -fsSL -o "${iconDir}/${id}.png" "${iconSrc app}" || true
            if [ ! -s "${iconDir}/${id}.png" ]; then
              rm -f "${iconDir}/${id}.png"
              warnEcho "webapps: no icon for '${id}' - set programs.webapps.apps.${id}.iconUrl (try https://dashboardicons.com)"
            fi
          fi
        '')
        cfg.apps));
  };
}
