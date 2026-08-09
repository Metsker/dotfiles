{
  flake.modules.homeManager.metsker = { dotfile, ... }: {
    programs.yazi = {
      enable = true;
      # enableFishIntegration = true;
    };

    xdg.configFile.yazi = { source = dotfile "yazi"; recursive = true; };
  };
}
