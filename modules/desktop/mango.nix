{ inputs, ... }:

# Desktop profile: mango as the compositor. noctalia is the shell on every profile, so it lives in
# session.nix; this file holds only what mango itself needs.
# Picked in the greeter as "Mango (UWSM)".
{
  flake.modules.nixos.base = { pkgs, ... }: {
    imports = [ inputs.mango.nixosModules.mango ];

    programs.mango = {
      enable = true;
      package = pkgs.mangowm;
      addLoginEntry = false; # uwsm-managed session entry only
    };

    programs.uwsm.waylandCompositors.mango = {
      prettyName = "Mango";
      comment = "Mango managed by uwsm";
      binPath = "/run/current-system/sw/bin/mango";
    };

    # Merges into the defaults mango's own module sets (wlr for ScreenCast/Screenshot).
    xdg.portal.config.mango."org.freedesktop.impl.portal.FileChooser" = "kde";

    nixpkgs.overlays = [
      # Exposes the flake input under pkgs so the tool wrappers can list it in runtimeInputs.
      (final: prev: {
        mangowm = inputs.mango.packages.${prev.stdenv.hostPlatform.system}.default;
      })
      # xdpw offers only 24-bit BG24 shm on NVIDIA GLES2; Chromium needs 32-bit - breaks Discord screenshare.
      # Patch = upstream PR 386 + XBGR/ABGR fallbacks. Drop when https://github.com/emersion/xdg-desktop-portal-wlr/issues/385 is fixed.
      # The 2-buffer pool still starves the capture loop with Electron consumers (PR 396 was rejected as a workaround);
      # drop the buffer-count patch once an unpatched xdpw holds 30fps to Discord without "out of buffers".
      (final: prev: {
        xdg-desktop-portal-wlr = prev.xdg-desktop-portal-wlr.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            ../../patches/xdpw-shm-fallback-formats.diff
            ../../patches/xdpw-buffer-count.diff
          ];
        });
      })
    ];
  };

  flake.modules.homeManager.metsker = { dotfile, ... }: {
    xdg.configFile.mango = { source = dotfile "mango"; recursive = true; };
  };
}
