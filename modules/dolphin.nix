{
  # Dolphin, the default file manager. The KF6 stack behind it is already resident - the kde
  # file-chooser portal in desktop.nix pulls it in - so this module costs about 19 MiB of its own.
  flake.modules.nixos.base = { pkgs, ... }: {
    # kio-admin registers its polkit action and system-bus helper only from the system profile; the
    # home copy below is the one that lands on QT_PLUGIN_PATH, so it is listed in both.
    environment.systemPackages = [ pkgs.kdePackages.kio-admin ];
  };

  flake.modules.homeManager.metsker = { pkgs, ... }: {
    home.packages = with pkgs.kdePackages; [
      dolphin
      ark # Extract Here and Compress in the context menu, dolphin's answer to thunar-archive-plugin
      kio-admin
      kdegraphics-thumbnailers # raw, mobipocket, postscript and blender previews
      ffmpegthumbs # video previews; images and pdf come from kio-extras, installed by theming.nix
    ] ++ [
      (pkgs.writeShellApplication {
        name = "image-info";
        runtimeInputs = with pkgs; [ imagemagick libnotify coreutils ];
        text = builtins.readFile ../scripts/image-info.sh;
      })
    ];

    xdg.mimeApps.defaultApplications."inode/directory" = "org.kde.dolphin.desktop";

    # Dolphin reads image dimensions only out of baloo's index - its Dimensions column, its tooltips
    # and the Details tab of the properties dialog all go through KBalooRolesProvider, and it never
    # extracts them itself. Rather than run an indexer over the whole home for one number, this asks
    # for it per file. KF6 ignores a service menu whose desktop file is not executable.
    xdg.dataFile."kio/servicemenus/image-info.desktop" = {
      executable = true;
      text = ''
        [Desktop Entry]
        Type=Service
        MimeType=image/*;
        Actions=imageInfo

        [Desktop Action imageInfo]
        Name=Image size
        Icon=image-x-generic
        Exec=image-info %F
      '';
    };
  };
}
