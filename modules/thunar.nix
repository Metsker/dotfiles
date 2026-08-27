{
  # The GTK file manager, no longer the default one. It stays for its own sake and because gvfs
  # and tumbler come with it - dolphin serves mounts and thumbnails through kio instead.
  flake.modules.nixos.base = { pkgs, ... }: {
    # gvfs gives thunar trash and removable-device mounts; dolphin uses kio for both instead.
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
  };

  flake.modules.homeManager.metsker = {
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
  };
}
