{
  flake.modules.nixos.base = { pkgs, ... }: {
    programs.dconf.enable = true;

    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-color-emoji
      noto-fonts-cjk-sans
    ];
  };

  flake.modules.homeManager.metsker = { config, lib, pkgs, ... }: {
    home.file.".local/share/fonts/JetBrainsMono".source =
      "${pkgs.nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono";

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
      font = {
        name = "JetBrainsMono Nerd Font";
        size = 10;
        package = pkgs.nerd-fonts.jetbrains-mono;
      };
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
      # qtct carries noctalia's palette but never reports a color scheme: qt6ct inherits
      # QGenericUnixTheme without overriding appearance(), and the portal listener lives in
      # QGnomeTheme, so QStyleHints::colorScheme() stays Unknown and QML/WebEngine apps render light.
      # plasma-integration reads the scheme out of kdeglobals, which is what noctalia writes.
      platformTheme.name = "kde";
      # Naming the package pins this to the Qt6 style; the default would add breeze.qt5 and drag the
      # whole KF5 tree in behind it. Nothing here is Qt5 any more - see the tiled overlay in dev.nix.
      style = {
        name = "breeze";
        package = pkgs.kdePackages.breeze;
      };

      # kwriteconfig6 edits kdeglobals in place and leaves it writable, which the merge needs - a
      # home.file symlink into the store would make noctalia's apply.py fail on open(). It only
      # rewrites the keys the color scheme names, so these two sections survive a theme switch.
      kde.settings.kdeglobals = {
        # Qt reads a font per role and falls back to its own default for any role left unset, so
        # every one of them has to name the family or dolphin keeps Noto Sans in its menus.
        General = {
          font = "JetBrainsMono Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
          fixed = "JetBrainsMono Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
          menuFont = "JetBrainsMono Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
          toolBarFont = "JetBrainsMono Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
          smallestReadableFont = "JetBrainsMono Nerd Font,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
        };
        WM.activeFont = "JetBrainsMono Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
        # Qt has no icon theme of its own; without this Qt apps fall back to hicolor and show blanks.
        Icons.Theme = "Papirus-Dark";
      };
    };

    # Previews in the kde file dialog come from KIO's thumbnail worker, which ships only in kio-extras.
    home.packages = [ pkgs.kdePackages.kio-extras ];

    # Hide KDE System Settings from the noctalia launcher - platformTheme "kde" pulls it in as a
    # dependency, and it is useless without a Plasma session (still runnable via `systemsettings`).
    xdg.desktopEntries.systemsettings = {
      name = "System Settings";
      exec = "systemsettings";
      noDisplay = true;
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
