{
  flake.modules.nixos.base = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.wget ];

    programs.ssh.startAgent = true;

    system.stateVersion = "26.05";

    # system.autoUpgrade = {
    #   enable = true;
    #   dates = "weekly";
    # };
  };

  flake.modules.homeManager.metsker = { dotfile, ... }: {
    home.stateVersion = "26.05";

    # Leftover: no hyprland here, but the config is still tracked and linked.
    xdg.configFile.hypr = { source = dotfile "hypr"; recursive = true; };
  };
}
