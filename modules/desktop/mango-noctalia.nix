{ inputs, ... }:

# Desktop profile: mango as the compositor, noctalia as the bar/shell/launcher.
# Self-contained - every package, config symlink and script that only this pair needs lives here.
# Picked in the greeter as "Mango (UWSM)"; the shell binds to wayland-session@mango.target so it
# stays down when the other profile is running.
let
  target = "wayland-session@mango.target";
in
{
  flake.modules.nixos.base = { pkgs, ... }: {
    imports = [ inputs.mango.nixosModules.mango ];

    programs.mango = {
      enable = true;
      package = pkgs.mangowm;
      addLoginEntry = false; # uwsm-managed session entry only
    };

    # The instance name uwsm derives from this binary's basename is what `target` above refers to.
    programs.uwsm.waylandCompositors.mango = {
      prettyName = "Mango";
      comment = "Mango managed by uwsm";
      binPath = "/run/current-system/sw/bin/mango";
    };

    # Merges into the defaults mango's own module sets (wlr for ScreenCast/Screenshot).
    xdg.portal.config.mango."org.freedesktop.impl.portal.FileChooser" = "kde";

    nix.settings.extra-substituters = [ "https://noctalia.cachix.org" ];
    nix.settings.extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];

    nixpkgs.overlays = [
      # Exposes the flake input under pkgs so the tool wrappers can list it in runtimeInputs.
      (final: prev: {
        mangowm = inputs.mango.packages.${prev.stdenv.hostPlatform.system}.default;
      })
      # xdpw offers only 24-bit BG24 shm on NVIDIA GLES2; Chromium needs 32-bit - breaks Discord screenshare.
      # Patch = upstream PR 386 + XBGR/ABGR fallbacks. Drop when https://github.com/emersion/xdg-desktop-portal-wlr/issues/385 is fixed.
      # The 2-buffer pool still starves the capture loop with Electron consumers; drop the buffer-count patch when PR 396 lands.
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

  flake.modules.homeManager.metsker = { config, lib, pkgs, dotfile, ... }: {
    imports = [ inputs.noctalia.homeModules.default ];

    xdg.configFile.mango = { source = dotfile "mango"; recursive = true; };

    programs.noctalia = {
      enable = true;
      systemd.enable = true;
    };

    # The module hardcodes graphical-session.target, which both profiles reach; re-point the unit
    # at mango's uwsm instance so noctalia does not also come up under the hyprland profile.
    systemd.user.services.noctalia.Unit.PartOf = lib.mkForce [ target ];
    systemd.user.services.noctalia.Unit.After = lib.mkForce [ target ];
    systemd.user.services.noctalia.Install.WantedBy = lib.mkForce [ target ];

    home.file.".local/state/noctalia/settings.toml".source = dotfile "noctalia/settings.toml";

    home.packages = with pkgs; [
      (writeShellApplication {
        name = "record";
        runtimeInputs = [ config.programs.noctalia.package procps gnused ];
        text = builtins.readFile ../../scripts/record.sh;
      })
    ];
  };
}
