{
  # nixpkgs pins tiled to Qt5 - a leftover from libsForQt5.callPackage that survived the by-name move,
  # not a version lag (1.12.2 is current, and upstream's own flake builds with qt6.full). That pin
  # breaks theming: no Qt5 plasma-integration exists any more, so a Qt5 tiled resolves no platform
  # theme and falls back to Qt's light default palette. Nobody has filed the qt6Packages switch
  # upstream, so this drops only once someone sends that PR - not on the next version bump.
  flake.modules.nixos.base.nixpkgs.overlays = [
    (final: prev: {
      tiled = (prev.tiled.override { libsForQt5 = final.qt6Packages; }).overrideAttrs (old: {
        # wrapQtAppsHook reads qtPluginPrefix off qtbase itself; the combined qt env does not carry it.
        buildInputs = old.buildInputs ++ [ final.qt6Packages.qtbase ];
      });
    })
  ];

  flake.modules.homeManager.metsker = { pkgs, ... }: {
    home.packages = with pkgs; [
      gcc
      gnumake
      ripgrep
      fzf
      fd
      jq
      tealdeer
      tree-sitter

      nodejs
      bun
      typescript
      python3
      rustc
      cargo
      rustfmt
      rust-analyzer

      nil
      nixpkgs-fmt
      lua-language-server
      stylua

      godot
      tiled

      # Tiled ships MIME types for .tmx/.tsx only, so a project file lands on text/plain.
      (writeTextDir "share/mime/packages/tiled-project.xml" ''
        <?xml version="1.0" encoding="UTF-8"?>
        <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
          <mime-type type="application/x-tiled-project">
            <comment>Tiled project</comment>
            <generic-icon name="application-x-tiled"/>
            <glob pattern="*.tiled-project"/>
            <sub-class-of type="application/json"/>
          </mime-type>
        </mime-info>
      '')
    ];

    xdg.mimeApps.defaultApplications = {
      "application/x-tiled-project" = "org.mapeditor.Tiled.desktop";
    };
  };
}
