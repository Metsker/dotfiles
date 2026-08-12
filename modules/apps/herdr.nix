{
  flake.modules.homeManager.metsker = { pkgs, dotfile, ... }: {
    home.packages = [ pkgs.herdr ];
    xdg.configFile."herdr/config.toml".source = dotfile "herdr/config.toml";
  };
}
