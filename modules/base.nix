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
  };
}
