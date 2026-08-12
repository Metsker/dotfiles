{
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
