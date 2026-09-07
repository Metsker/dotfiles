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
      hyperfine

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

      # Claude Code's LSP tool has no server of its own: the typescript-lsp plugin in
      # settings.json only tells it to look for this binary on PATH.
      typescript-language-server
      biome

      # Noctalia plugins are Luau; luau-lsp type-checks them against the
      # noctalia.d.luau definitions in config/noctalia/plugins.
      luau
      luau-lsp

      # adb/fastboot; systemd 258 handles the uaccess rules, so no udev package is needed.
      android-tools

      godot
      tiled
      oxipng
      gifski

      herdr

      # Installs a version-matched herdr and neovim on a Debian host over SSH, so
      # `herdr --remote <host>` has a server to attach to. See the script's header.
      (writeShellApplication {
        name = "bootstrap-remote";
        runtimeInputs = [ openssh ];
        text = builtins.readFile ../scripts/bootstrap-remote.sh;
      })

      # Aseprite's batch CLI, out of the Steam copy rather than pkgs.aseprite.
      #
      # Both are 1.3.18.3, but Aseprite is unfree, so Hydra never builds it and the
      # nixpkgs one is a local Aseprite-plus-Skia compile for a binary already on disk.
      # `-b` opens no window, so this runs with neither DISPLAY nor WAYLAND_DISPLAY set
      # and an agent can drive it.
      #
      # Two traps this wrapper cannot fix, only document. steam-run gives /tmp a private
      # tmpfs, so an export written there exits 0 and leaves no file behind - write to the
      # repository or $HOME instead. And --data omits meta.frameTags unless --list-tags
      # rides along on the same command, which is the field AnimatedSprite reads:
      #
      #   aseprite -b in.aseprite --sheet out.png --data out.json \
      #     --format json-array --sheet-pack --trim --list-tags
      #
      # Drop once pkgs.aseprite is something Hydra ships prebuilt.
      (writeShellApplication {
        name = "aseprite";
        runtimeInputs = [ steam-run ];
        text = ''
          ase="$HOME/.local/share/Steam/steamapps/common/Aseprite/aseprite"
          if [ ! -x "$ase" ]; then
            echo "aseprite: not installed by Steam at $ase" >&2
            exit 1
          fi
          exec steam-run "$ase" "$@"
        '';
      })

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

    # Per-project toolchains: a project's own flake beats pinning every game's bun and
    # node version into this one home profile. nix-direnv is what makes the reload cached
    # rather than a full eval on every cd.
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    xdg.configFile."herdr/config.toml".source = dotfile "herdr/config.toml";
    xdg.configFile."herdr/plugins/config/cloudmanic.herdr-plus".source =
      dotfile "herdr/plugins/config/cloudmanic.herdr-plus";

    # DELETE once nixpkgs has herdr > 0.8.2 - herdrdev/herdr#3415 is fixed on master
    # and queued for the next release.
    #
    # Started from a terminal, the herdr server inherits that terminal's cgroup, so on
    # logout or reboot systemd SIGTERMs it and all of its panes at once. The shells die
    # in ~20ms and herdr reacts ~180ms later, by which point it has been told every pane
    # exited - it closes the emptied workspaces and its shutdown save persists that. Four
    # workspaces came back as one on 2026-09-07, and the same race cost a session on
    # mango, so this is the cgroup rather than any one compositor.
    #
    # Its own unit exists only so KillMode=mixed applies: SIGTERM reaches the server
    # alone, which then stops its panes itself and saves the full tree - the path that
    # already works for a manual `herdr server stop`. The compositor's teardown cannot
    # reach the panes any more either, since they now live in this unit's cgroup.
    #
    # Note this starts the server at login rather than on the first `herdr`, so the saved
    # session is restored (and its agents resumed) before the terminal is opened.
    systemd.user.services.herdr = {
      Unit = {
        Description = "herdr session server";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        # A server the client already spawned still holds the socket, so the first
        # activation cannot bind; give up rather than retry until the next login.
        StartLimitIntervalSec = 60;
        StartLimitBurst = 3;
      };
      Service = {
        ExecStart = "${pkgs.herdr}/bin/herdr server";
        KillMode = "mixed";
        TimeoutStopSec = 30;
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
