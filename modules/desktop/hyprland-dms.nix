{ inputs, ... }:

# Desktop profile: hyprland as the compositor, DankMaterialShell as the bar/shell/launcher.
# Self-contained - every package, config symlink and setting that only this pair needs lives here.
# Picked in the greeter as "Hyprland (uwsm-managed)"; the shell binds to
# wayland-session@hyprland.target so it stays down when the other profile is running.
let
  # uwsm names the instance after the session's desktop-entry id, ".desktop" and all - confirmed
  # against the live `wayland-session@hyprland.desktop.target`, not the bare name it looks like.
  target = "wayland-session@hyprland.desktop.target";
in
{
  flake.modules.nixos.base = {
    programs.hyprland = {
      enable = true;
      # Ships its own uwsm session entry (`uwsm start -e -D Hyprland hyprland.desktop`), whose
      # desktop-entry id is the instance name `target` above refers to. It also leaves a plain
      # "Hyprland" entry in the greeter - that one bypasses uwsm, so no shell starts. Pick
      # "Hyprland (uwsm-managed)".
      withUWSM = true;
    };

    # Replaces the package's own hyprland-portals.conf, so its default line has to be repeated here.
    xdg.portal.config.hyprland = {
      default = [ "hyprland" "gtk" ];
      "org.freedesktop.impl.portal.FileChooser" = "kde";
    };
  };

  flake.modules.homeManager.metsker = { dotfile, ... }: {
    imports = [ inputs.dank-material-shell.homeModules.dank-material-shell ];

    programs.dank-material-shell = {
      enable = true;
      systemd.enable = true;
      # Not graphical-session.target: both profiles reach that, and only this one wants dms.
      systemd.target = target;
    };

    # `dms setup` generates ~/.config/hypr/hyprland.lua and the dms/ fragments beside it, and the
    # Settings pages rewrite them at runtime, so the generated ones are not tracked - run
    # `dms setup` once on a fresh machine. These two are the exceptions: setup leaves a non-empty
    # outputs.lua alone, and it never rewrites binds-user.lua, so both are safe to own here.
    # Everything personal goes in binds-user.lua, which hyprland.lua requires last.
    xdg.configFile."hypr/dms/binds-user.lua".source = dotfile "hypr/dms/binds-user.lua";
    xdg.configFile."hypr/dms/outputs.lua".source = dotfile "hypr/dms/outputs.lua";
  };
}
