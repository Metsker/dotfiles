{ inputs, ... }:

# Desktop profile: umbriel as the compositor. noctalia is the shell on every profile, so it lives in
# session.nix; this file holds only what umbriel itself needs.
# Picked in the greeter as "Umbriel".
#
# Umbriel is noctalia's own compositor, so the pairing needs no glue: its example config already
# carries noctalia's window and layer rules, and noctalia renders a palette into
# ~/.config/umbriel/noctalia.toml, which config.toml includes.
#
# Like driftwm it is not uwsm-managed - start-umbriel runs umbriel.service, which brings up
# umbriel-session.target and graphical-session.target behind it.
{
  flake.modules.nixos.base = { pkgs, ... }: {
    imports = [ inputs.umbriel.nixosModules.default ];

    programs.umbriel.enable = true;
    programs.umbriel.package = pkgs.umbriel;

    # Exposes the flake input under pkgs so the shared tool wrappers can list it in runtimeInputs.
    nixpkgs.overlays = [ inputs.umbriel.overlays.default ];

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
