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

    # Exposes the flake input under pkgs so desktop-tools.nix can list it in runtimeInputs.
    nixpkgs.overlays = [
      (final: prev: {
        mangowm = inputs.mango.packages.${prev.stdenv.hostPlatform.system}.default;
      })
    ];
  };

  flake.modules.homeManager.metsker = { pkgs, dotfile, ... }: {
    xdg.configFile.mango = { source = dotfile "mango"; recursive = true; };
    xdg.configFile.uwsm = { source = dotfile "uwsm"; recursive = true; };

    home.packages = [ pkgs.xwayland ];
  };
}
