{ inputs, ... }:

# Desktop profile: driftwm as the compositor. noctalia is the shell on every profile, so it lives in
# session.nix; this file holds only what driftwm itself needs.
# Picked in the greeter as "driftwm".
#
# driftwm ships its own driftwm-session wrapper and a driftwm.service that pulls
# graphical-session.target up behind it, so there is no uwsm target for this one.
{
  flake.modules.nixos.base = { pkgs, ... }: {
    imports = [ inputs.driftwm.nixosModules.driftwm ];

    programs.driftwm.enable = true;
    # The input's own module defaults this to the flake's package, which the overlay below misses.
    programs.driftwm.package = pkgs.driftwm;

    # Exposes the flake input under pkgs so the shared tool wrappers can list it in runtimeInputs.
    nixpkgs.overlays = [
      (final: prev: {
        driftwm = (inputs.driftwm.packages.${prev.stdenv.hostPlatform.system}.default).overrideAttrs (old: {
          # Upstream's postInstall globs extras/wallpapers/*.glsl, which is not recursive, so only
          # dot_grid.glsl ships and the nine under animated/, static/ and textured/ are left out.
          # Drop when that glob reaches into the subdirectories.
          postInstall = old.postInstall + ''
            cp -r extras/wallpapers/. $out/share/driftwm/wallpapers/
          '';
        });
      })
    ];

    # The module's mkDefault list loses to session.nix's kde entry, which would drop both of these.
    xdg.portal.extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-wlr
    ];

    # Replaces the package's own driftwm-portals.conf, so its lines have to be repeated here.
    # Its Secret=gnome-keyring line is dropped along with the keyring below.
    xdg.portal.config.driftwm = {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = "wlr";
      "org.freedesktop.impl.portal.Screenshot" = "wlr";
      "org.freedesktop.impl.portal.Inhibit" = "none";
      "org.freedesktop.impl.portal.FileChooser" = "kde";
    };

    # The module turns the keyring on by default; nothing else on this host uses one.
    services.gnome.gnome-keyring.enable = false;

    # The background shader is named by a stable path in config.toml rather than a store path that
    # moves every rebuild, and only listed prefixes reach the system profile's share directory.
    environment.pathsToLink = [ "/share/driftwm" ];
  };

  flake.modules.homeManager.metsker = { pkgs, dotfile, ... }: {
    # A whole directory, not `recursive`: `recursive` copies each file into the store, and driftwm
    # inotifies the config directory, so a symlinked file inside a real one defeats the watch.
    xdg.configFile.driftwm.source = dotfile "driftwm";

    home.packages = with pkgs; [
      playerctl # driftwm's default XF86Audio* binds
    ];
  };
}
