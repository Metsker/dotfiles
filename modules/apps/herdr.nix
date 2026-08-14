{
  flake.modules.homeManager.metsker = { pkgs, dotfile, ... }: {
    home.packages = [ pkgs.herdr ];
    xdg.configFile."herdr/config.toml".source = dotfile "herdr/config.toml";

    # herdr-plus reads its quick actions from herdr's per-plugin config dir
    xdg.configFile."herdr/plugins/config/cloudmanic.herdr-plus/quick-actions".source =
      dotfile "herdr/plugins/config/cloudmanic.herdr-plus/quick-actions";
  };
}
