{ inputs, ... }:

# Everyday desktop applications: browser, file manager, media, chat, art, VPN.
# The ones that carry real weight of their own live next door - claude.nix,
# webapps.nix, gaming.nix.
{
  flake.modules.nixos.base = { config, pkgs, ... }: {
    # gvfs gives the file manager trash and removable-device mounts.
    services.gvfs.enable = true;

    # The module also pulls in xfconf, which is where thunar keeps its settings.
    programs.thunar = {
      enable = true;
      # Thunar has no archive handling of its own; this is what puts Extract Here and Compress in
      # the context menu. It drives engrampa through a wrapper script.
      plugins = [ pkgs.thunar-archive-plugin ];
    };

    # Thunar draws no thumbnails on its own; tumbler is the D-Bus thumbnailer it asks.
    services.tumbler.enable = true;

    programs.amnezia-vpn.enable = true;

    boot.extraModulePackages = with config.boot.kernelPackages; [ amneziawg ];

    # Amnezia's "launch at startup" entry must exist (it gates launch-minimized), but mango's
    # autostart already launches the client gated on nm-online; mask the duplicate XDG unit.
    systemd.user.units."app-AmneziaVPN@autostart.service".enable = false;

    environment.systemPackages = with pkgs; [
      unzip
      zip
      p7zip # engrampa shells out to 7z for 7z/zip-with-password archives
      unar # engrampa shells out to lsar/unar for rar
      amneziawg-tools
    ];

    # Telegram's miniapp webview dies with "Error 71 (Protocol error)" on NVIDIA - webkitgtk's
    # dmabuf renderer cannot import NVIDIA's buffers into this wlroots session.
    # Drop once that renderer survives an NVIDIA wlroots session.
    nixpkgs.overlays = [
      (final: prev: {
        telegram-desktop = prev.telegram-desktop.overrideAttrs (old: {
          qtWrapperArgs = old.qtWrapperArgs ++ [ "--set" "WEBKIT_DISABLE_DMABUF_RENDERER" "1" ];
        });
      })
    ];
  };

  flake.modules.homeManager.metsker = { pkgs, ... }: {
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
        # Default 2 (auto) only picks the portal when sandboxed; 1 forces it, so uploads get the portal picker.
        "widget.use-xdg-desktop-portal.file-picker" = 1;
      };
    };

    home.packages = with pkgs; [
      engrampa
      imv
      mpv
      ffmpeg
      imagemagick
      telegram-desktop
      discord
      krita
      spotify
    ];

    # Thunar's two side tools; both are reachable from inside thunar itself.
    xdg.desktopEntries.thunar-settings = {
      name = "Thunar Preferences";
      exec = "thunar-settings";
      noDisplay = true;
    };
    xdg.desktopEntries.thunar-bulk-rename = {
      name = "Bulk Rename";
      exec = "thunar --bulk-rename %F";
      noDisplay = true;
    };

    xdg.mimeApps.defaultApplications = {
      "text/html" = "zen-beta.desktop";
      "application/xhtml+xml" = "zen-beta.desktop";
      "x-scheme-handler/http" = "zen-beta.desktop";
      "x-scheme-handler/https" = "zen-beta.desktop";
      "x-scheme-handler/about" = "zen-beta.desktop";
      "x-scheme-handler/unknown" = "zen-beta.desktop";

      "inode/directory" = "thunar.desktop";
      "application/zip" = "engrampa.desktop";
      "application/x-7z-compressed" = "engrampa.desktop";
      "application/vnd.rar" = "engrampa.desktop";
      "application/x-tar" = "engrampa.desktop";
      "application/x-compressed-tar" = "engrampa.desktop";
      "application/x-xz-compressed-tar" = "engrampa.desktop";

      "image/png" = "imv-dir.desktop";
      "image/jpeg" = "imv-dir.desktop";
      "image/gif" = "imv-dir.desktop";
      "image/webp" = "imv-dir.desktop";
      "image/bmp" = "imv-dir.desktop";
      "image/tiff" = "imv-dir.desktop";
      "image/svg+xml" = "imv-dir.desktop";
      "image/avif" = "imv-dir.desktop";
      "image/heif" = "imv-dir.desktop";
      "video/mp4" = "mpv.desktop";
      "video/webm" = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "video/quicktime" = "mpv.desktop";
      "video/x-msvideo" = "mpv.desktop";
      "video/mpeg" = "mpv.desktop";
    };
  };
}
