{ inputs, ... }:

# Desktop profile: umbriel as the compositor. noctalia is the shell on every profile, so it lives in
# session.nix; this file holds only what umbriel itself needs.
# Picked in the greeter as "Umbriel".
#
# Umbriel is noctalia's own compositor, so the pairing needs no glue: its example config already
# carries noctalia's window and layer rules, and noctalia renders a palette into
# ~/.config/umbriel/noctalia.toml, which config.toml includes.
#
# It is not uwsm-managed - start-umbriel runs umbriel.service, which brings up
# umbriel-session.target and graphical-session.target behind it.
#
# It is also the profile boot autologins into, which session.nix sets up.
{
  flake.modules.nixos.base = { pkgs, ... }: {
    imports = [ inputs.umbriel.nixosModules.default ];

    programs.umbriel.enable = true;
    programs.umbriel.package = pkgs.umbriel;

    # Exposes the flake input under pkgs so the shared tool wrappers can list it in runtimeInputs.
    nixpkgs.overlays = [
      inputs.umbriel.overlays.default
      # Satellite focuses override-redirect windows, and Steam closes a menu the moment focus
      # lands on it - so every Steam dropdown dies. Source is PR 494, which never focuses an
      # override-redirect window and hands WM_TAKE_FOCUS clients the choice, as Hyprland's XWM
      # does. Drop when https://github.com/Supreeeme/xwayland-satellite/pull/494 reaches nixpkgs.
      (final: prev: {
        xwayland-satellite = prev.xwayland-satellite.overrideAttrs (old:
          let
            src = final.fetchFromGitHub {
              owner = "3akev";
              repo = "xwayland-satellite";
              rev = "9d51b59ff3c38464e7654096c9b10a8052a26b25";
              hash = "sha256-hJWNd9MqNzKEDV59E45jeqtbSz/+xrg/Comg6GjAKDo=";
            };
          in
          {
            version = "${old.version}-pr494";
            inherit src;
            # buildRustPackage derives cargoDeps from the original src, so it has to be rebuilt too.
            cargoDeps = final.rustPlatform.fetchCargoVendor {
              inherit src;
              hash = "sha256-s1gl9eR6Mt2QLrhfcowstPFjzwE/lz4PJhJzWYHoIHg=";
            };
          });
      })
    ];

    # Merges into the module's own default of [ "umbriel" "gtk" ]; umbriel's portal handles the
    # screencast side, so this is the only key worth overriding.
    xdg.portal.config.umbriel."org.freedesktop.impl.portal.FileChooser" = "kde";
  };

  flake.modules.homeManager.metsker = { dotfile, ... }: {
    # A whole directory, not `recursive`: `recursive` copies each file into the store, and noctalia's
    # theme template writes noctalia.toml into this directory, which config.toml then includes.
    xdg.configFile.umbriel.source = dotfile "umbriel";
  };
}
