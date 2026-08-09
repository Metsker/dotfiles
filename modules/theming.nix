{
  flake.modules.nixos.base = {
    qt.enable = true;
    programs.dconf.enable = true;
  };

  flake.modules.homeManager.metsker = { config, lib, pkgs, ... }: {
    home.pointerCursor = {
      enable = true;
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
      size = 24;
      gtk.enable = true;
      x11.enable = true;
    };

    gtk = {
      enable = true;
      theme = {
        name = "adw-gtk3-dark";
        package = pkgs.adw-gtk3;
      };
      iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };
      # adw-gtk3 pairs a 25%-alpha selection tint with a light label, but thunar blanks that fill
      # (its own CSS sets .standard-view .view:selected transparent) and paints the accent solid,
      # leaving light text on light green. Repeat the import noctalia's apply.sh looks for: seeing
      # it there, the script leaves this read-only store symlink alone instead of rewriting it.
      gtk3.extraCss = ''
        @import url("noctalia.css");

        .standard-view .view:selected,
        .standard-view .view:selected:focus {
          color: @accent_fg_color;
        }

        /* thunar_icon_renderer_color_selected multiplies the icon by a background-color it reads from
           :selected while focused and :active once not, so an undefined :active multiplies to black. */
        .standard-view .view:selected,
        .standard-view .view:active {
          background-color: @accent_bg_color;
        }
      '';
    };

    # noctalia's papirus-icons template recolors folders in place, so the theme has to be writable:
    # the store copy is not, and the /usr/share fallback it looks for does not exist here. Papirus
    # comes along because Papirus-Dark is a shell - every size >= 32px symlinks into ../Papirus.
    home.activation.papirusWritable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      icons="$HOME/.local/share/icons"
      src="${config.gtk.iconTheme.package}/share/icons"
      if [ "$(cat "$icons/.papirus-source" 2>/dev/null)" != "$src" ]; then
        run mkdir -p "$icons"
        run rm -rf "$icons/Papirus" "$icons/Papirus-Dark"
        run cp -a "$src/Papirus" "$src/Papirus-Dark" "$icons/"
        run chmod -R u+w "$icons/Papirus" "$icons/Papirus-Dark"
        # The only sizes papirus-folders recolors that Papirus-Dark keeps its own copy of; the
        # content is byte-identical to Papirus's, so linking them lets one recolor cover both.
        for s in 22x22 24x24; do
          run rm -rf "$icons/Papirus-Dark/$s/places"
          run ln -s "../../Papirus/$s/places" "$icons/Papirus-Dark/$s/places"
        done
        # Rebuilt last, against the final layout: the copied cache pointed at the store and without
        # any cache GTK stats its way through every theme dir on each app start.
        for t in Papirus Papirus-Dark; do
          run ${pkgs.gtk4}/bin/gtk4-update-icon-cache -q -t -f "$icons/$t"
        done
        echo "$src" > "$icons/.papirus-source"
      fi
    '';

    qt = {
      enable = true;
      platformTheme.name = "qtct";
      qt6ctSettings.Appearance = {
        custom_palette = true;
        style = "Fusion";
        color_scheme_path = "${config.home.homeDirectory}/.config/qt6ct/colors/noctalia.conf";
        # Qt has no icon theme of its own; without this Qt apps fall back to hicolor and show blanks.
        icon_theme = "Papirus-Dark";
      };
    };

    # Hide the Qt5/Qt6 Settings tools from the noctalia launcher (still runnable via `qt5ct`/`qt6ct`).
    xdg.desktopEntries.qt5ct = {
      name = "Qt5 Settings";
      exec = "qt5ct";
      noDisplay = true;
    };
    xdg.desktopEntries.qt6ct = {
      name = "Qt6 Settings";
      exec = "qt6ct";
      noDisplay = true;
    };
  };
}
