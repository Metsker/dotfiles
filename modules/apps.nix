{ inputs, ... }:

# Everyday desktop applications: browser, media, chat, art, VPN.
# The ones that carry real weight of their own live next door - claude.nix,
# webapps.nix, gaming.nix, and the two file managers in thunar.nix and dolphin.nix.
{
  flake.modules.nixos.base = { config, pkgs, ... }: {
    programs.amnezia-vpn.enable = true;

    boot.extraModulePackages = with config.boot.kernelPackages; [ amneziawg ];

    # Amnezia's "launch at startup" entry must exist (it gates launch-minimized), but mango's
    # autostart already launches the client gated on nm-online; mask the duplicate XDG unit.
    systemd.user.units."app-AmneziaVPN@autostart.service".enable = false;

    # openFirewall punches 53317 tcp+udp; the firewall is on by default, and without
    # that hole discovery finds nothing and an incoming transfer never connects.
    programs.localsend = {
      enable = true;
      openFirewall = true;
    };

    environment.systemPackages = with pkgs; [
      unzip
      zip
      p7zip # engrampa shells out to 7z for 7z/zip-with-password archives
      unar # engrampa shells out to lsar/unar for rar
      amneziawg-tools
      btop
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
      # Also the session's Secret Service provider, which is what lets noctalia persist credentials.
      keepassxc
    ];

    xdg.mimeApps.defaultApplications = {
      "text/html" = "zen-beta.desktop";
      "application/xhtml+xml" = "zen-beta.desktop";
      "x-scheme-handler/http" = "zen-beta.desktop";
      "x-scheme-handler/https" = "zen-beta.desktop";
      "x-scheme-handler/about" = "zen-beta.desktop";
      "x-scheme-handler/unknown" = "zen-beta.desktop";

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
