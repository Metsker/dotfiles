{
  flake.modules.nixos.base = { pkgs, ... }: {
    programs.dconf.enable = true;
    # Defaults to the X server's switch; uncached, every GTK app stats hicolor and breeze on start.
    gtk.iconCache.enable = true;

    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-color-emoji
      noto-fonts-cjk-sans
    ];
  };

  flake.modules.homeManager.metsker = { pkgs, ... }: {
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
        size = 11;
        package = pkgs.nerd-fonts.jetbrains-mono;
      };
      theme = {
        name = "adw-gtk3-dark";
        package = pkgs.adw-gtk3;
      };
      # Its folders follow the color scheme (FollowsColorScheme), which noctalia, luciole and KDE apps fill from the palette.
      iconTheme = {
        name = "Gruvbox-Plus-Dark";
        package = pkgs.gruvbox-plus-icons;
      };
      # Repeat the import noctalia's apply.sh looks for: seeing it there, the script leaves this
      # read-only store symlink alone instead of rewriting it.
      gtk3.extraCss = ''
        @import url("noctalia.css");
      '';
    };

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
        # every one of them has to name the family or Qt apps keep Noto Sans in their menus.
        General = {
          font = "JetBrainsMono Nerd Font,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
          fixed = "JetBrainsMono Nerd Font,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
          menuFont = "JetBrainsMono Nerd Font,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
          toolBarFont = "JetBrainsMono Nerd Font,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
          smallestReadableFont = "JetBrainsMono Nerd Font,9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
        };
        WM.activeFont = "JetBrainsMono Nerd Font,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
        # Qt has no icon theme of its own; without this Qt apps fall back to hicolor and show blanks.
        Icons.Theme = "Gruvbox-Plus-Dark";
      };
    };

    # Gruvbox Plus inherits breeze-dark for every icon it does not draw.
    home.packages = [ pkgs.kdePackages.breeze-icons ];

    # Hide KDE System Settings from the noctalia launcher - platformTheme "kde" pulls it in as a
    # dependency, and it is useless without a Plasma session (still runnable via `systemsettings`).
    xdg.desktopEntries.systemsettings = {
      name = "System Settings";
      exec = "systemsettings";
      noDisplay = true;
    };
  };
}
