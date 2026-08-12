{
  flake.modules.homeManager.metsker = { pkgs, config, ... }: {
    home.packages = [
      (pkgs.writeShellApplication {
        name = "record";
        runtimeInputs = [ config.programs.noctalia.package pkgs.procps pkgs.gnused ];
        text = builtins.readFile ../scripts/record.sh;
      })
    ];
  };

  flake.modules.nixos.base = { pkgs, ... }: {
    xdg.portal.wlr.settings.screencast = {
      chooser_type = "simple";
      chooser_cmd = "${pkgs.slurp}/bin/slurp -f 'Monitor: %o' -or";
    };

    programs.gpu-screen-recorder.enable = true;

    # xdpw offers only 24-bit BG24 shm on NVIDIA GLES2; Chromium needs 32-bit - breaks Discord screenshare.
    # Patch = upstream PR 386 + XBGR/ABGR fallbacks. Drop when https://github.com/emersion/xdg-desktop-portal-wlr/issues/385 is fixed.
    # The 2-buffer pool still starves the capture loop with Electron consumers; drop the buffer-count patch when PR 396 lands.
    nixpkgs.overlays = [
      (final: prev: {
        xdg-desktop-portal-wlr = prev.xdg-desktop-portal-wlr.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            ../patches/xdpw-shm-fallback-formats.diff
            ../patches/xdpw-buffer-count.diff
          ];
        });
      })
    ];
  };
}
