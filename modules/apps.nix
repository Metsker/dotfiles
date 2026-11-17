{ inputs, ... }:

# Everyday desktop applications: browser, media, chat, art, notes.
# The ones that carry real weight of their own live next door - vpn.nix, agents.nix,
# webapps.nix, gaming.nix, and the file manager in dolphin.nix.
{
  flake.modules.nixos.base = { pkgs, ... }: {
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
      btop
    ];

    nixpkgs.overlays = [
      # Not in nixpkgs; pkgs.helium for both the browser below and webapps.nix.
      inputs.helium.overlays.default

      (final: prev: {
        # Telegram's miniapp webview dies with "Error 71 (Protocol error)" on NVIDIA - webkitgtk's
        # dmabuf renderer cannot import NVIDIA's buffers into this wlroots session.
        # Drop once that renderer survives an NVIDIA wlroots session.
        telegram-desktop = prev.telegram-desktop.overrideAttrs (old: {
          qtWrapperArgs = old.qtWrapperArgs ++ [ "--set" "WEBKIT_DISABLE_DMABUF_RENDERER" "1" ];
        });

        # Discord reads its VA surfaces without syncing, so nvidia-vaapi-driver 0.0.18 hands it stale
        # frames and streams stutter; software decode here only. Drop once nixpkgs ships nvidia-vaapi-driver > 0.0.18 (#455 fix).
        discord = final.symlinkJoin {
          name = "discord-${prev.discord.version}";
          paths = [ prev.discord ];
          nativeBuildInputs = [ final.makeWrapper ];
          postBuild = ''
            rm $out/bin/Discord $out/bin/discord
            makeWrapper ${prev.discord}/bin/Discord $out/bin/Discord --set LIBVA_DRIVER_NAME none
            ln -s $out/bin/Discord $out/bin/discord
          '';
          inherit (prev.discord) meta;
        };
      })
    ];
  };

  flake.modules.homeManager.metsker = { pkgs, dotfile, ... }:
    let
      natsumi = pkgs.applyPatches {
        name = "natsumi";
        src = inputs.natsumi;
        # Firefox renamed the pinned-tab variables, which collapses the pinned grid to one column; drop once upstream uses the new names.
        patches = [ ../patches/natsumi-pinned-tabs-vars.patch ];
      };

      # Natsumi's chrome folder with fx-autoconfig's loader, its manifest pointed at Natsumi's scripts.
      natsumiChrome = pkgs.runCommand "natsumi-chrome" { } ''
        mkdir -p $out/utils $out/CSS $out/resources
        cp -r ${natsumi}/{natsumi,userChrome.css,userContent.css,natsumi-config.css} $out/
        cp ${inputs.fx-autoconfig}/profile/chrome/utils/*.mjs $out/utils/
        # The noctalia palette loader joins Natsumi's scripts, the one folder fx-autoconfig reads.
        chmod u+w $out/natsumi/scripts
        cp ${../config/glide/noctalia-sync.sys.mjs} $out/natsumi/scripts/noctalia-sync.sys.mjs
        cat > $out/utils/chrome.manifest <<EOF
        content userchromejs ./
        content userscripts ../natsumi/scripts/
        skin userstyles classic/1.0 ../CSS/
        content userchrome ../resources/
        content natsumi ../natsumi/
        content natsumi-icons ../natsumi/icons/
        EOF
      '';
    in
    {
      imports = [
        inputs.zen-browser.homeModules.default
        inputs.glide.homeModules.default
      ];

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

      programs.glide-browser = {
        enable = true;
        package = pkgs.wrapFirefox inputs.glide.packages.${pkgs.stdenv.hostPlatform.system}.glide-browser-bin-unwrapped {
          pname = "glide-browser";
          # fx-autoconfig's loader runs as mozilla.cfg, which needs privileged JS.
          extraAutoConfig = ''pref("general.config.sandbox_enabled", false);'';
          extraPrefsFiles = [ "${inputs.fx-autoconfig}/program/config.js" ];
        };
        profiles.default.settings = {
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
          # Natsumi's preferences page needs fx-autoconfig to run on every document load.
          "userChromeJS.persistent_domcontent_callback" = true;
          # The updater would write into the read-only chrome folder; the flake input pins Natsumi instead.
          "natsumi.updater.disabled" = true;
          # Not one of Natsumi's accents: noctalia's palette (config/noctalia/templates/glide.css) supplies it.
          "natsumi.theme.accent-color" = "noctalia";
        };
      };

      home.file.".config/glide/glide/default/chrome" = {
        source = natsumiChrome;
        # The startup cache keeps serving the previous scripts after an update.
        onChange = ''rm -rf "$HOME/.cache/glide/glide/default/startupCache"'';
      };

      # Linked file by file: the profile lives in ~/.config/glide/glide and must stay out of the repo.
      # Other themings tried (custom CSS, FF Ultima) sit unlinked in config/glide/archive.
      xdg.configFile."glide/glide.ts".source = dotfile "glide/glide.ts";

      home.packages = with pkgs; [
        helium
        engrampa
        imv
        mpv
        ffmpeg
        imagemagick
        telegram-desktop
        discord
        krita
        blender
        spotify
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
