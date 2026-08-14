{ inputs, ... }:

{
  flake.modules.nixos.base = { pkgs, ... }: {
    imports = [ inputs.mango.nixosModules.mango ];

    programs.mango = {
      enable = true;
      package = pkgs.mangowm;
      addLoginEntry = false; # uwsm-managed session entry only
    };

    # Runs mango under systemd user units: app scopes tear down cleanly, graphical-session.target works.
    programs.uwsm = {
      enable = true;
      waylandCompositors.mango = {
        prettyName = "Mango";
        comment = "Mango managed by uwsm";
        binPath = "/run/current-system/sw/bin/mango";
      };
    };

    # Auto-login into mango at boot (LUKS passphrase already gates access); greeter only shows after logout.
    services.greetd.settings.initial_session = {
      command = "uwsm start -F -- /run/current-system/sw/bin/mango";
      user = "metsker";
    };

    # Electron apps (Discord) ignore SIGTERM and stall logout for 90s; SIGKILL them after 10s instead.
    systemd.user.settings.Manager.DefaultTimeoutStopSec = "10s";

    # mango drops WLR_INPUT_DEVICE_TOUCH on the floor and never advertises WL_SEAT_CAPABILITY_TOUCH,
    # so a touchscreen does nothing at all. Patch is mango PR 888 (itself a port of dwl's
    # touch-input patch), with its three dispatchers changed from int32_t to void - the PR branch
    # carries a dispatcher-return refactor that is not in main. Drop when PR 888 merges.
    nixpkgs.overlays = [
      (final: prev: {
        mangowm = inputs.mango.packages.${prev.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ../../patches/mango-touch-input.diff ];
        });
      })
    ];
  };

  flake.modules.homeManager.metsker = { pkgs, dotfile, ... }: {
    xdg.configFile.mango = { source = dotfile "mango"; recursive = true; };
    xdg.configFile.uwsm = { source = dotfile "uwsm"; recursive = true; };

    home.packages = [ pkgs.xwayland ];
  };
}
