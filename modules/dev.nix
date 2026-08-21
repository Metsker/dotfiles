{
  flake.modules.nixos.base = { pkgs, ... }: {
    # nixpkgs pins tiled to Qt5 - a leftover from libsForQt5.callPackage that survived the by-name move,
    # not a version lag (1.12.2 is current, and upstream's own flake builds with qt6.full). That pin
    # breaks theming: no Qt5 plasma-integration exists any more, so a Qt5 tiled resolves no platform
    # theme and falls back to Qt's light default palette. Nobody has filed the qt6Packages switch
    # upstream, so this drops only once someone sends that PR - not on the next version bump.
    nixpkgs.overlays = [
      (final: prev: {
        tiled = (prev.tiled.override { libsForQt5 = final.qt6Packages; }).overrideAttrs (old: {
          # wrapQtAppsHook reads qtPluginPrefix off qtbase itself; the combined qt env does not carry it.
          buildInputs = old.buildInputs ++ [ final.qt6Packages.qtbase ];
        });
      })
    ];

    # Playwright browsers, once, for everything on the machine.
    #
    # The browsers npm fetches are dynamically linked against libraries that are on
    # no path here, so `playwright install` in any project downloads a few hundred
    # megabytes that can never launch - it fails complaining about libgtk-3.so.0 and
    # a page of friends. nixpkgs patches its own set instead, and
    # PLAYWRIGHT_BROWSERS_PATH is what points a project's playwright at those.
    #
    # Same derivation pkgs.playwright-mcp already bakes into its own wrapper (see
    # claude.nix), so the browser Claude drives and the browser a test suite drives
    # cannot drift apart.
    #
    # The catch is worth writing down, because the error it gives is not obvious: a
    # browser directory in there is named for its *revision*, not for a version
    # range, so npm playwright only finds these when its version matches the
    # driver's. Anything else says "Executable doesn't exist at
    # .../chromium_headless_shell-1234" and suggests running `playwright install`,
    # which is the one thing that cannot help. PLAYWRIGHT_NIX_VERSION is that
    # version, so a project can pin against it rather than guess:
    #
    #   npm i -D playwright@$PLAYWRIGHT_NIX_VERSION
    environment.sessionVariables = {
      PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
      PLAYWRIGHT_NIX_VERSION = pkgs.playwright-driver.version;
      # Nothing it could download would run, so fail fast on a version mismatch
      # rather than spending the bandwidth to fail later.
      PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
    };
  };

  flake.modules.homeManager.metsker = { pkgs, dotfile, ... }: {
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

      herdr

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

    xdg.configFile."herdr/config.toml".source = dotfile "herdr/config.toml";

    # herdr-plus reads its quick actions from herdr's per-plugin config dir
    xdg.configFile."herdr/plugins/config/cloudmanic.herdr-plus/quick-actions".source =
      dotfile "herdr/plugins/config/cloudmanic.herdr-plus/quick-actions";
  };
}
