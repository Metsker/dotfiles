{
  flake.modules.nixos.base = { pkgs, ... }: {
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

    environment.systemPackages = with pkgs; [
      unzip
      zip
      unar # engrampa shells out to lsar/unar for rar
    ];
  };

  flake.modules.homeManager.metsker = { pkgs, ... }: {
    home.packages = [ pkgs.engrampa ];

    # Same for thunar's two side tools; both are reachable from inside thunar itself.
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
      "inode/directory" = "thunar.desktop";
      "application/zip" = "engrampa.desktop";
      "application/x-7z-compressed" = "engrampa.desktop";
      "application/vnd.rar" = "engrampa.desktop";
      "application/x-tar" = "engrampa.desktop";
      "application/x-compressed-tar" = "engrampa.desktop";
      "application/x-xz-compressed-tar" = "engrampa.desktop";
    };
  };
}
