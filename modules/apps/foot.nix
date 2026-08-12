{
  flake.modules.nixos.base = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.foot ];
  };

  flake.modules.homeManager.metsker = { dotfile, ... }: {
    xdg.configFile.foot = { source = dotfile "foot"; recursive = true; };
  };
}
